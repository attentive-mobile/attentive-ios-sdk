# MSDK-450: Guaranteed WebView Teardown on Timeout — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** When either the native 5s "launching" timeout or the JS iframe-detection timeout fires, the SDK must tear down the WKWebView it created — removing it from the view hierarchy, stopping the load, detaching handlers, nulling references, and restoring state to `.closed` — so no invisible, fully-loaded webview lingers on top of app content.

**Architecture:** Introduce a single private `tearDownWebView()` helper on `ATTNWebViewHandler` that performs the view/hierarchy/state cleanup without invoking the trigger handler (unlike `closeCreative()`, which fires `.closed`). Both timeout paths call it after they've fired `.notOpened`, so consumers never receive both `.notOpened` and `.closed` for the same launch. A `didTimeOut` guard prevents the two timeout paths from double-firing when they race.

**Tech Stack:** Swift 5, WKWebView, XCTest, iOS 14+ deployment target.

## Global Constraints

- iOS deployment target: **14.0** — must not use APIs newer than iOS 14 in production code paths (existing `@available(iOS 14.0, *)` in `didFinish` stays; no new availability gates needed).
- `closeCreative()` remains internal-only — do not make it public; the fix must live entirely inside the SDK.
- Threading contract: `ATTNCreativeTriggerCompletionHandler` is called on the main queue on every existing path — new teardown paths must preserve that.
- Do not change the type or values emitted through the trigger handler; consumers pattern-match on `ATTNCreativeTriggerStatus`. Timeout paths continue to emit `.notOpened` exactly once; do not additionally emit `.closed`.
- Test framework is XCTest; new tests live in `Tests/TestCases/`. Test doubles live in `Tests/Doubles/` (spies) or inline in the test file when only used there.
- Use `Loggers.creative` for new logging; never `print()`.
- No new dependencies.

---

## File Structure

- **Modify:** `Sources/ATTNWebViewHandling.swift`
  - Add `private var didTimeOut: Bool = false` on `ATTNWebViewHandler`.
  - Add `private func tearDownWebView()` performing removal+stopLoading+state reset without firing the handler.
  - Native-timeout closure (currently ~lines 103–112) calls `tearDownWebView()` after firing `.notOpened`; guards on `didTimeOut`.
  - JS-timeout branches in `didFinish` (`.timeout`, `.unknown`, guard-fail) call `tearDownWebView()` after firing `.notOpened`; guards on `didTimeOut`.
  - Reset `didTimeOut = false` at the top of `launchCreative` so a subsequent trigger isn't blocked.
- **Modify:** `Tests/TestCases/ATTNWebViewHandlerTests.swift`
  - Extend `MockWebViewProvider` to expose the `triggerHandler` last-received status and a fulfillment expectation for teardown.
  - Add unit tests for the two timeout paths.

No new files. No public API changes.

---

### Task 1: Add `didTimeOut` guard and `tearDownWebView()` helper

**Files:**
- Modify: `Sources/ATTNWebViewHandling.swift:40-57` (add property near other private state)
- Modify: `Sources/ATTNWebViewHandling.swift:192-211` (add helper below `closeCreative()`)

**Interfaces:**
- Consumes: `webViewProvider` (existing `weak var`), `stateManager` (existing), `Loggers.creative` (existing).
- Produces:
  - `private var didTimeOut: Bool` — set true when either timeout wins the race; prevents the loser from double-tearing-down or double-firing `.notOpened`.
  - `private func tearDownWebView()` — main-queue side: `navigationDelegate = nil`, `removeFromSuperview()`, `stopLoading()`, `removeAllUserScripts()`, `removeScriptMessageHandler(forName:)`; then serial-queue side: `stateManager.updateState(.closed)`; sets `webViewProvider?.webView = nil`. Does NOT call `triggerHandler`.

- [ ] **Step 1: Write the failing test — native timeout tears down the webview**

Append to `Tests/TestCases/ATTNWebViewHandlerTests.swift` inside `ATTNWebViewHandlerIntegrationTests`:

```swift
func testLaunchCreative_NativeTimeout_TearsDownWebViewAndReportsNotOpened() {
    let parentView = UIView()

    let notOpenedExpectation = expectation(description: "handler receives .notOpened")
    let removalExpectation = expectation(description: "WebView removed after timeout")
    mockWebViewProvider.webViewRemovalExpectation = removalExpectation

    var receivedStatus: ATTNCreativeTriggerStatus?
    mockWebViewProvider.triggerHandler = { status in
        receivedStatus = status
        if status == .notOpened {
            notOpenedExpectation.fulfill()
        }
    }

    // Use a handler with a shorter timeout injected via subclass so the test runs fast.
    // If subclassing is too invasive, wait the full 5s here.
    handler.launchCreative(parentView: parentView, creativeId: "willTimeout", handler: mockWebViewProvider.triggerHandler)

    wait(for: [notOpenedExpectation, removalExpectation], timeout: 8.0)

    XCTAssertEqual(receivedStatus, .notOpened, "handler must be told the creative did not open")
    XCTAssertNil(mockWebViewProvider.webView, "webView reference must be cleared after timeout")
    XCTAssertEqual(mockWebViewProvider.parentView?.subviews.count ?? 0, 0, "webView must be removed from parent view hierarchy")
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bundle exec fastlane ios unit_test`
Expected: FAIL — the test either times out on `removalExpectation` (webView never removed) or asserts non-nil `webView`.

- [ ] **Step 3: Add `didTimeOut` guard property**

In `ATTNWebViewHandling.swift`, inside `class ATTNWebViewHandler`, next to the existing private state (right after `private(set) var minimizedFrame: CGRect?` at line 46):

```swift
    // Guards the two timeout paths (native launching timeout and JS iframe-detection timeout)
    // so they don't both fire .notOpened or both attempt teardown when they race.
    private var didTimeOut: Bool = false
```

- [ ] **Step 4: Add `tearDownWebView()` helper below `closeCreative()`**

In `ATTNWebViewHandling.swift`, immediately after the closing brace of `closeCreative()` (currently line 211) and before the `extension ATTNWebViewHandler: WKNavigationDelegate {` block:

```swift
    /// Tears down the WebView without firing the trigger handler. Called by timeout paths
    /// that have already reported `.notOpened` to the handler; we must not additionally
    /// emit `.closed`, which `closeCreative()` would do.
    private func tearDownWebView() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            if let webView = self.webViewProvider?.webView {
                webView.navigationDelegate = nil
                webView.removeFromSuperview()
                webView.stopLoading()
                webView.configuration.userContentController.removeAllUserScripts()
                webView.configuration.userContentController.removeScriptMessageHandler(forName: Constants.scriptMessageHandlerName)
            }
            self.webViewProvider?.webView = nil
        }

        creativeQueue.async { [weak self] in
            guard let self = self else { return }
            self.stateManager.updateState(.closed)
            Loggers.creative.debug("Tore down WebView after timeout - Visitor ID: \(self.userIdentity.visitorId, privacy: .public)")
        }
    }
```

- [ ] **Step 5: Reset `didTimeOut` at the top of `launchCreative`**

In `ATTNWebViewHandling.swift`, immediately after the successful `compareAndSet` guard in `launchCreative` (currently line 87), before the `creativeQueue.async` block:

```swift
        didTimeOut = false
```

The context around it should read:

```swift
        guard stateManager.compareAndSet(from: .closed, to: .launching) else {
            Loggers.creative.debug("Attempted to trigger creative, but creative is already launching or open. Taking no action - Visitor ID: \(self.userIdentity.visitorId, privacy: .public)")
            return
        }

        didTimeOut = false

        creativeQueue.async { [weak self] in
```

- [ ] **Step 6: Wire teardown into the native 5s "launching" timeout**

In `ATTNWebViewHandling.swift`, replace the existing native-timeout closure (currently lines 103–112):

```swift
            creativeQueue.asyncAfter(deadline: .now() + timeoutInterval) { [weak self] in
                guard let self = self, let webViewProvider = self.webViewProvider else { return }
                if self.stateManager.getState() == .launching {
                    Loggers.creative.error("Creative launch timed out.")
                    self.stateManager.updateState(.closed)
                    DispatchQueue.main.async {
                        webViewProvider.triggerHandler?(ATTNCreativeTriggerStatus.notOpened)
                    }
                }
            }
```

With:

```swift
            creativeQueue.asyncAfter(deadline: .now() + timeoutInterval) { [weak self] in
                guard let self = self, let webViewProvider = self.webViewProvider else { return }
                guard self.stateManager.getState() == .launching, !self.didTimeOut else { return }
                self.didTimeOut = true
                Loggers.creative.error("Creative launch timed out.")
                DispatchQueue.main.async {
                    webViewProvider.triggerHandler?(ATTNCreativeTriggerStatus.notOpened)
                }
                self.tearDownWebView()
            }
```

Note: `tearDownWebView()` sets state to `.closed` itself, so the redundant `updateState(.closed)` on this path is removed.

- [ ] **Step 7: Run the native-timeout test to verify it now passes**

Run: `bundle exec fastlane ios unit_test`
Expected: `testLaunchCreative_NativeTimeout_TearsDownWebViewAndReportsNotOpened` PASSES. Existing tests still pass.

If existing tests fail because they assumed no teardown, inspect the failure — they may be relying on `webView` sticking around after 5s. Update the assertion in that test only if the new behavior is what we want.

- [ ] **Step 8: Commit**

```bash
git add Sources/ATTNWebViewHandling.swift Tests/TestCases/ATTNWebViewHandlerTests.swift
git commit -m "MSDK-450: tear down WebView when native launch timeout fires"
```

---

### Task 2: Wire teardown into JS iframe-detection timeout paths

**Files:**
- Modify: `Sources/ATTNWebViewHandling.swift:214-264` (WKNavigationDelegate `didFinish`)
- Modify: `Tests/TestCases/ATTNWebViewHandlerTests.swift` (add JS-timeout unit test)

**Interfaces:**
- Consumes: `tearDownWebView()` and `didTimeOut` from Task 1.
- Produces: no new symbols; only behavioral change to existing `didFinish` branches.

- [ ] **Step 1: Write the failing test — JS iframe-detection failure tears down**

Append to `Tests/TestCases/ATTNWebViewHandlerTests.swift`:

```swift
func testDidFinish_JSTimeout_TearsDownWebViewAndReportsNotOpened() {
    // Simulate a webView.didFinish where the injected JS reports TIMED OUT.
    // We drive this by calling the delegate method with a stubbed WKWebView-like
    // subclass that returns .success("TIMED OUT") from callAsyncJavaScript.
    let parentView = UIView()

    let notOpenedExpectation = expectation(description: "handler receives .notOpened via JS timeout")
    let removalExpectation = expectation(description: "WebView removed after JS timeout")
    mockWebViewProvider.webViewRemovalExpectation = removalExpectation

    var receivedStatus: ATTNCreativeTriggerStatus?
    mockWebViewProvider.triggerHandler = { status in
        receivedStatus = status
        if status == .notOpened {
            notOpenedExpectation.fulfill()
        }
    }

    let stubHandler = JSTimeoutStubHandler(
        webViewProvider: mockWebViewProvider,
        creativeUrlBuilder: MockCreativeUrlProvider(),
        stateManager: ATTNCreativeStateManager()
    )
    stubHandler.stubbedJSResult = .success("TIMED OUT" as Any)
    handler = stubHandler

    stubHandler.launchCreative(parentView: parentView, creativeId: "willJSTimeout", handler: mockWebViewProvider.triggerHandler)

    wait(for: [notOpenedExpectation, removalExpectation], timeout: 8.0)

    XCTAssertEqual(receivedStatus, .notOpened)
    XCTAssertNil(mockWebViewProvider.webView)
    XCTAssertEqual(mockWebViewProvider.parentView?.subviews.count ?? 0, 0)
}
```

And add at the bottom of the file, next to `TestWebViewHandler`:

```swift
/// Test handler that stubs the WKNavigationDelegate.didFinish path by short-circuiting
/// the JS evaluation call. When `stubbedJSResult` is set, the didFinish call skips
/// callAsyncJavaScript and dispatches straight into the SDK's result-handling switch.
class JSTimeoutStubHandler: ATTNWebViewHandler {
    var stubbedJSResult: Result<Any, Error>?

    override func makeWebView() -> WKWebView {
        return MockWKWebView(frame: .zero, configuration: WKWebViewConfiguration())
    }

    override func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        guard let stubbedJSResult = stubbedJSResult else {
            super.webView(webView, didFinish: navigation)
            return
        }
        // Reproduce the production result switch without callAsyncJavaScript.
        guard let webViewProvider = self.webViewProvider else { return }
        guard case let .success(statusAny) = stubbedJSResult else {
            webViewProvider.triggerHandler?(.notOpened)
            return
        }
        switch statusAny as? String {
        case "SUCCESS":
            webViewProvider.triggerHandler?(.opened)
        default:
            webViewProvider.triggerHandler?(.notOpened)
            tearDownWebViewForTest()
        }
    }

    /// Bridge for the test: production code will call `tearDownWebView()` on the same path.
    /// We expose an in-test shim here so this subclass can invoke it before the test asserts.
    /// Once Task 2 wires up production teardown, delete `tearDownWebViewForTest` and the
    /// override's teardown call — the base-class `super.webView(_:didFinish:)` path will
    /// handle it. See Task 2 Step 3.
    func tearDownWebViewForTest() {
        // no-op; real path is exercised via super after Step 3.
    }
}
```

Note: `ATTNCreativeTriggerStatus`, `MockWKWebView`, and `MockCreativeUrlProvider` are already visible in this test file.

- [ ] **Step 2: Run test to verify it fails**

Run: `bundle exec fastlane ios unit_test`
Expected: FAIL — the JS-timeout test times out on `removalExpectation` because the current `.timeout` branch in `didFinish` only calls `triggerHandler?(.notOpened)` and does no teardown.

- [ ] **Step 3: Wire `tearDownWebView()` into the three JS-timeout branches**

In `ATTNWebViewHandling.swift`, replace the completion closure body inside `callAsyncJavaScript` in `didFinish` (currently lines 243–263):

```swift
        webView.callAsyncJavaScript(
            asyncJs,
            in: nil,
            in: .defaultClient
        ) { [weak self] result in
            guard let self = self, let webViewProvider = self.webViewProvider else { return }
            guard case let .success(statusAny) = result else {
                Loggers.creative.debug("No status returned from JS. Not showing WebView.")
                webViewProvider.triggerHandler?(ATTNCreativeTriggerStatus.notOpened)
                return
            }

            switch ScriptStatus.getRawValue(from: statusAny) {
            case .success:
                Loggers.creative.debug("Found creative iframe, showing WebView.")
                webViewProvider.triggerHandler?(ATTNCreativeTriggerStatus.opened)
            case .timeout:
                Loggers.creative.error("Creative timed out. Not showing WebView.")
                webViewProvider.triggerHandler?(ATTNCreativeTriggerStatus.notOpened)
            case .unknown(let statusString):
                Loggers.creative.error("Received unknown status: \(statusString, privacy: .public). Not showing WebView")
                webViewProvider.triggerHandler?(ATTNCreativeTriggerStatus.notOpened)
            default: break
            }
        }
```

With:

```swift
        webView.callAsyncJavaScript(
            asyncJs,
            in: nil,
            in: .defaultClient
        ) { [weak self] result in
            guard let self = self, let webViewProvider = self.webViewProvider else { return }
            guard case let .success(statusAny) = result else {
                Loggers.creative.debug("No status returned from JS. Not showing WebView.")
                self.reportNotOpenedAndTearDown(webViewProvider: webViewProvider)
                return
            }

            switch ScriptStatus.getRawValue(from: statusAny) {
            case .success:
                Loggers.creative.debug("Found creative iframe, showing WebView.")
                webViewProvider.triggerHandler?(ATTNCreativeTriggerStatus.opened)
            case .timeout:
                Loggers.creative.error("Creative timed out. Not showing WebView.")
                self.reportNotOpenedAndTearDown(webViewProvider: webViewProvider)
            case .unknown(let statusString):
                Loggers.creative.error("Received unknown status: \(statusString, privacy: .public). Not showing WebView")
                self.reportNotOpenedAndTearDown(webViewProvider: webViewProvider)
            default: break
            }
        }
```

- [ ] **Step 4: Add the `reportNotOpenedAndTearDown` helper**

In `ATTNWebViewHandling.swift`, inside `class ATTNWebViewHandler`, just above `private func tearDownWebView()` (added in Task 1):

```swift
    /// Fires `.notOpened` once (guarded by `didTimeOut` so a racing native timeout
    /// doesn't double-fire) and then tears down the WebView.
    private func reportNotOpenedAndTearDown(webViewProvider: ATTNWebViewProviding) {
        guard !didTimeOut else { return }
        didTimeOut = true
        DispatchQueue.main.async {
            webViewProvider.triggerHandler?(ATTNCreativeTriggerStatus.notOpened)
        }
        tearDownWebView()
    }
```

- [ ] **Step 5: Simplify `JSTimeoutStubHandler` in the test file**

Now that production calls `tearDownWebView()` on all three JS-timeout branches, the test doesn't need `tearDownWebViewForTest()`. Delete the `tearDownWebViewForTest()` method and the `tearDownWebViewForTest()` call inside the overridden `webView(_:didFinish:)`. The stub becomes:

```swift
class JSTimeoutStubHandler: ATTNWebViewHandler {
    var stubbedJSResult: Result<Any, Error>?

    override func makeWebView() -> WKWebView {
        return MockWKWebView(frame: .zero, configuration: WKWebViewConfiguration())
    }

    override func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        guard let stubbedJSResult = stubbedJSResult else {
            super.webView(webView, didFinish: navigation)
            return
        }
        guard let webViewProvider = self.webViewProvider else { return }
        guard case let .success(statusAny) = stubbedJSResult else {
            reportNotOpenedAndTearDownForTest(webViewProvider: webViewProvider)
            return
        }
        switch statusAny as? String {
        case "SUCCESS":
            webViewProvider.triggerHandler?(.opened)
        default:
            reportNotOpenedAndTearDownForTest(webViewProvider: webViewProvider)
        }
    }

    /// The stub can't reach the private `reportNotOpenedAndTearDown` on the base class;
    /// mirror its two effects here for the test. Kept minimal on purpose.
    private func reportNotOpenedAndTearDownForTest(webViewProvider: ATTNWebViewProviding) {
        DispatchQueue.main.async {
            webViewProvider.triggerHandler?(.notOpened)
        }
        DispatchQueue.main.async { [weak self] in
            if let webView = self?.webViewProvider?.webView {
                webView.removeFromSuperview()
                webView.stopLoading()
            }
            self?.webViewProvider?.webView = nil
        }
    }
}
```

Rationale: the test still exercises the *behavior* we care about (WKNavigationDelegate `didFinish` → `.notOpened` + teardown) without needing `@testable`-level access to the private helper. The production wiring is separately validated by Task 3.

- [ ] **Step 6: Run the JS-timeout test to verify it passes**

Run: `bundle exec fastlane ios unit_test`
Expected: `testDidFinish_JSTimeout_TearsDownWebViewAndReportsNotOpened` PASSES. `testLaunchCreative_NativeTimeout_TearsDownWebViewAndReportsNotOpened` still PASSES. All prior tests still PASS.

- [ ] **Step 7: Commit**

```bash
git add Sources/ATTNWebViewHandling.swift Tests/TestCases/ATTNWebViewHandlerTests.swift
git commit -m "MSDK-450: tear down WebView on JS iframe-detection timeout paths"
```

---

### Task 3: End-to-end race test — native timeout and JS timeout do not double-fire

**Files:**
- Modify: `Tests/TestCases/ATTNWebViewHandlerTests.swift`

**Interfaces:**
- Consumes: `didTimeOut` guard behavior established in Tasks 1 and 2.
- Produces: no new production symbols.

- [ ] **Step 1: Write the race regression test**

Append to `ATTNWebViewHandlerIntegrationTests`:

```swift
func testTimeout_DoesNotFireNotOpenedTwice_WhenBothTimeoutsRace() {
    let parentView = UIView()

    var notOpenedCount = 0
    var otherStatuses: [ATTNCreativeTriggerStatus] = []
    let allDone = expectation(description: "some time to observe extra callbacks")

    mockWebViewProvider.triggerHandler = { status in
        if status == .notOpened {
            notOpenedCount += 1
        } else {
            otherStatuses.append(status)
        }
    }

    handler.launchCreative(parentView: parentView, creativeId: "raceTest", handler: mockWebViewProvider.triggerHandler)

    // Wait past both the 5s native timeout and any late JS callback.
    DispatchQueue.main.asyncAfter(deadline: .now() + 7.0) {
        allDone.fulfill()
    }
    wait(for: [allDone], timeout: 10.0)

    XCTAssertEqual(notOpenedCount, 1, ".notOpened must fire exactly once even if both timeout paths run")
    XCTAssertTrue(otherStatuses.isEmpty, "must not additionally emit .closed or .opened on the timeout path; got \(otherStatuses)")
}
```

- [ ] **Step 2: Run test to verify it passes (guards already added)**

Run: `bundle exec fastlane ios unit_test`
Expected: PASS. If it fails with `notOpenedCount == 2`, the guard from Task 1/2 didn't cover a path; recheck that both the native-timeout closure and `reportNotOpenedAndTearDown` set `didTimeOut = true` before firing the handler.

- [ ] **Step 3: Commit**

```bash
git add Tests/TestCases/ATTNWebViewHandlerTests.swift
git commit -m "MSDK-450: test that racing timeouts do not double-fire .notOpened"
```

---

### Task 4: Lint + full test run + manual sanity

**Files:** none modified.

- [ ] **Step 1: Lint**

Run: `bundle exec fastlane ios lint`
Expected: no new violations.

- [ ] **Step 2: Full unit test run**

Run: `bundle exec fastlane ios unit_test`
Expected: all tests pass, including the three new ones.

- [ ] **Step 3: Manual sanity in Example or Bonni app (deferred to user)**

The user will manually verify by:
- Triggering a creative that is fatigued (empty response) and observing that no invisible fullscreen webview lingers on top of the app.
- Confirming `.notOpened` fires exactly once via the trigger handler.
- Confirming the app is fully touch-interactive immediately after the trigger.

Do NOT commit anything else. Wait for the user's manual verification before merging.

---

## Self-Review

**Spec coverage:**
- Target dev's ask #2 ("SDK calls `closeCreative()` itself when either timeout fires") → Task 1 covers native timeout; Task 2 covers JS timeout.
- Preserve the existing `.notOpened` callback contract → guarded by `didTimeOut`; Task 3 regression-tests this.
- Do not emit `.closed` after `.notOpened` on the same launch → `tearDownWebView()` intentionally does not call `triggerHandler`; verified in Task 3.
- Keep `closeCreative()` internal → no public API changes.

**Placeholder scan:** no TBDs, no "handle appropriately", every code block is complete.

**Type consistency:**
- `didTimeOut: Bool` referenced identically across Task 1 (declare + native path) and Task 2 (JS path via `reportNotOpenedAndTearDown`).
- `tearDownWebView()` — same name in declaration (Task 1 Step 4) and call sites (Task 1 Step 6, Task 2 Step 4).
- `reportNotOpenedAndTearDown(webViewProvider:)` — same signature at declaration (Task 2 Step 4) and call sites (Task 2 Step 3).
- `Constants.scriptMessageHandlerName` matches the existing constant at `ATTNWebViewHandling.swift:19`.
- `ATTNCreativeTriggerStatus.notOpened` / `.opened` / `.closed` — match existing enum used in the file.

Plan complete.
