//
//  ATTNWebViewHandlerTests.swift
//  attentive-ios-sdk Tests
//
//  Created by Adela Gao on 1/28/25.
//

// MARK: Integration tests

import Foundation
import UIKit
import WebKit
import XCTest

@testable import ATTNSDKFramework

// MARK: Integration tests

final class ATTNWebViewHandlerIntegrationTests: XCTestCase {

    var mockWebViewProvider: MockWebViewProvider!
    var mockUrlProvider: MockCreativeUrlProvider!
    var handler: ATTNWebViewHandler!

    /// Every `launchCreative` call arms a native teardown timer for
    /// `launchTimeoutInterval`. Tests that are NOT about that timer must use an
    /// interval that cannot elapse mid-test — otherwise every assertion between
    /// launch and close silently races the timer, and on a slow CI machine the
    /// timer wins and tears the webview down under the test's feet. Tests that
    /// ARE about the timer build their own handler via `makeHandler(timeout:)`.
    private static let neverFiresTimeout: TimeInterval = 3600

    override func setUp() {
        super.setUp()
        mockWebViewProvider = MockWebViewProvider()
        mockUrlProvider = MockCreativeUrlProvider()
        handler = makeHandler(timeout: Self.neverFiresTimeout)
    }

    private func makeHandler(timeout: TimeInterval) -> ATTNWebViewHandler {
        ATTNWebViewHandler(
            webViewProvider: mockWebViewProvider,
            creativeUrlBuilder: mockUrlProvider,
            stateManager: ATTNCreativeStateManager(),
            launchTimeoutInterval: timeout
        )
    }

    override func tearDown() {
        mockWebViewProvider = nil
        mockUrlProvider = nil
        handler = nil
        super.tearDown()
    }

    func testLaunchCreative_ShouldAddWebView() {
        let parentView = UIView()

        let expectation = self.expectation(description: "WebView should be added")
        mockWebViewProvider.webViewSetupExpectation = expectation

        handler.launchCreative(parentView: parentView, creativeId: "testCreative")

        waitForExpectations(timeout: 30.0) { error in
            XCTAssertNil(error, "WebView was not added in time")
        }

        XCTAssertNotNil(mockWebViewProvider.webView, "WebView should be initialized")
        XCTAssertEqual(mockWebViewProvider.parentView, parentView, "Parent view should be set correctly")
    }

    func testLaunchCreative_ShouldPreventDuplicateCreation() {
        let parentView = UIView()
        let expectation = self.expectation(description: "WebView should be set")

        expectation.expectedFulfillmentCount = 1
        mockWebViewProvider.webViewSetupExpectation = expectation

        // First call transitions state from .closed to .launching.
        // Second call sees state .launching and returns immediately.
        handler.launchCreative(parentView: parentView, creativeId: "first")
        handler.launchCreative(parentView: parentView, creativeId: "second")

        waitForExpectations(timeout: 30.0) { error in
            XCTAssertNil(error, "WebView should have been created by the first call")
        }

        XCTAssertEqual(mockWebViewProvider.webViewCreationCount, 1, "WebView should be created only once")
    }

    func testLaunchCreative_CompareAndSetShouldBeThreadSafe() {
        // Directly test that compareAndSet is safe under concurrent access.
        // Only one of many concurrent callers should succeed in transitioning
        // from .closed to .launching.
        let stateManager = ATTNCreativeStateManager()
        let iterations = 10
        let group = DispatchGroup()
        var successCount = 0
        let lock = NSLock()

        for _ in 0..<iterations {
            group.enter()
            Thread.detachNewThread {
                if stateManager.compareAndSet(from: .closed, to: .launching) {
                    lock.lock()
                    successCount += 1
                    lock.unlock()
                }
                group.leave()
            }
        }

        let result = group.wait(timeout: .now() + 10.0)
        XCTAssertEqual(result, .success, "All concurrent tasks should complete")
        XCTAssertEqual(successCount, 1, "Exactly one concurrent caller should win the compareAndSet race")
    }

    func testCloseCreative_ShouldRemoveWebView() {
        let parentView = UIView()

        handler.launchCreative(parentView: parentView, creativeId: "testCreative")

        let expectation = self.expectation(description: "WebView should be removed")
        mockWebViewProvider.webViewRemovalExpectation = expectation

        handler.closeCreative()

        waitForExpectations(timeout: 30.0) { error in
            XCTAssertNil(error, "WebView was not removed in time")
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {  // Wait to check for unexpected re-creation
            XCTAssertNil(self.mockWebViewProvider?.webView, "WebView should be nil after closing creative")
        }
    }

    func testLaunchCreative_NativeTimeout_TearsDownWebViewAndReportsNotOpened() {
        // This test IS about the native timeout — use a fast one so the test is
        // quick, and wait generously: the assertions are anchored on the
        // timeout's observable effects (callback + removal), not on wall clock.
        handler = makeHandler(timeout: 0.2)
        let parentView = UIView()

        let notOpenedExpectation = expectation(description: "handler receives .notOpened")
        let removalExpectation = expectation(description: "WebView removed after timeout")
        mockWebViewProvider.webViewRemovalExpectation = removalExpectation

        var receivedStatus: String?
        let handlerClosure: ATTNCreativeTriggerCompletionHandler = { status in
            receivedStatus = status
            if status == ATTNCreativeTriggerStatus.notOpened {
                notOpenedExpectation.fulfill()
            }
        }
        mockWebViewProvider.triggerHandler = handlerClosure

        handler.launchCreative(parentView: parentView, creativeId: "willTimeout", handler: handlerClosure)

        wait(for: [notOpenedExpectation, removalExpectation], timeout: 30.0)

        XCTAssertEqual(receivedStatus, ATTNCreativeTriggerStatus.notOpened, "handler must be told the creative did not open")
        XCTAssertNil(mockWebViewProvider.webView, "webView reference must be cleared after timeout")
        XCTAssertEqual(parentView.subviews.count, 0, "webView must be removed from parent view hierarchy")
    }

    func testDidFinish_JSTimeout_TearsDownWebViewAndReportsNotOpened() {
        let parentView = UIView()

        let notOpenedExpectation = expectation(description: "handler receives .notOpened via JS timeout")
        let removalExpectation = expectation(description: "WebView removed after JS timeout")
        mockWebViewProvider.webViewRemovalExpectation = removalExpectation

        var receivedStatus: String?
        let handlerClosure: ATTNCreativeTriggerCompletionHandler = { status in
            receivedStatus = status
            if status == ATTNCreativeTriggerStatus.notOpened {
                notOpenedExpectation.fulfill()
            }
        }
        mockWebViewProvider.triggerHandler = handlerClosure

        let stubHandler = JSTimeoutStubHandler(
            webViewProvider: mockWebViewProvider,
            creativeUrlBuilder: MockCreativeUrlProvider(),
            stateManager: ATTNCreativeStateManager(),
            launchTimeoutInterval: Self.neverFiresTimeout  // the JS path is driven manually; the native timer must never race it
        )
        stubHandler.stubbedJSResult = .success("TIMED OUT" as Any)
        handler = stubHandler

        let setupExpectation = expectation(description: "webView setup")
        mockWebViewProvider.webViewSetupExpectation = setupExpectation
        stubHandler.launchCreative(parentView: parentView, creativeId: "willJSTimeout", handler: handlerClosure)
        wait(for: [setupExpectation], timeout: 30.0)

        // MockWKWebView.load() doesn't trigger a real WKNavigation, so didFinish
        // won't fire on its own. Simulate WebKit invoking it — which then dispatches
        // to the stubbed JS result → real reportNotOpenedAndTearDown path.
        guard let webView = mockWebViewProvider.webView else {
            return XCTFail("expected webView after setup")
        }
        stubHandler.webView(webView, didFinish: nil)

        wait(for: [notOpenedExpectation, removalExpectation], timeout: 30.0)

        XCTAssertEqual(receivedStatus, ATTNCreativeTriggerStatus.notOpened)
        XCTAssertNil(mockWebViewProvider.webView)
        XCTAssertEqual(parentView.subviews.count, 0)
    }

    func testTimeout_DoesNotFireNotOpenedTwice_WhenBothTimeoutsRace() {
        // This test IS about the native timeout — use a fast one.
        handler = makeHandler(timeout: 0.2)
        let parentView = UIView()

        var notOpenedCount = 0
        var otherStatuses: [String] = []
        let firstNotOpened = expectation(description: "first .notOpened arrives")

        let handlerClosure: ATTNCreativeTriggerCompletionHandler = { status in
            if status == ATTNCreativeTriggerStatus.notOpened {
                notOpenedCount += 1
                if notOpenedCount == 1 { firstNotOpened.fulfill() }
            } else {
                otherStatuses.append(status)
            }
        }
        mockWebViewProvider.triggerHandler = handlerClosure

        handler.launchCreative(parentView: parentView, creativeId: "raceTest", handler: handlerClosure)

        // Anchor on the timeout's observable effect rather than wall clock: wait
        // (generously) for the first .notOpened, THEN hold a settle window in
        // which any duplicate would arrive. A fixed launch-anchored sleep flakes
        // when a loaded CI machine delays the first callback past the window.
        wait(for: [firstNotOpened], timeout: 30.0)

        let settled = expectation(description: "settle window for duplicate callbacks")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            settled.fulfill()
        }
        wait(for: [settled], timeout: 5.0)

        XCTAssertEqual(notOpenedCount, 1, ".notOpened must fire exactly once even if both timeout paths run")
        XCTAssertTrue(otherStatuses.isEmpty, "must not additionally emit .closed or .opened on the timeout path; got \(otherStatuses)")
    }

    func testMultiLaunch_StaleTimeoutCallback_DoesNotTearDownNewLaunch() {
        // Regression test for the epoch guard: a stale native-timeout callback
        // scheduled by launch #1 must NOT tear down launch #2's webview even though
        // launch #2 is currently in `.launching`. The epoch mechanism is what makes
        // that safe when the same handler is reused for multiple launches.
        let parentView = UIView()

        // Launch #1 → epoch 1.
        let firstSetup = expectation(description: "webView1 setup")
        mockWebViewProvider.webViewSetupExpectation = firstSetup
        handler.launchCreative(parentView: parentView, creativeId: "first")
        wait(for: [firstSetup], timeout: 30.0)

        // Close launch #1 so state → .closed and the next launch is allowed.
        let closeExpectation = expectation(description: "webView1 removed")
        mockWebViewProvider.webViewRemovalExpectation = closeExpectation
        handler.closeCreative()
        wait(for: [closeExpectation], timeout: 30.0)

        // Reset the fulfillment tracking so launch #2's setup expectation can fire.
        mockWebViewProvider.resetExpectations()

        // Launch #2 on the SAME handler → epoch 2. The stale-timeout callback is
        // injected manually below, so this test needs no live native timer — the
        // setUp handler's never-firing timeout means nothing races these asserts.
        let secondSetup = expectation(description: "webView2 setup")
        mockWebViewProvider.webViewSetupExpectation = secondSetup
        handler.launchCreative(parentView: parentView, creativeId: "second")
        wait(for: [secondSetup], timeout: 30.0)
        guard let webView2 = mockWebViewProvider.webView as? CustomWebView else {
            return XCTFail("expected CustomWebView after launch #2")
        }
        XCTAssertGreaterThanOrEqual(webView2.launchEpoch, 2, "launch #2 must have an epoch strictly greater than launch #1's")

        // Simulate launch #1's stale native-timeout firing while launch #2 is still
        // in `.launching`. It should be silently dropped by the epoch guard.
        handler.reportNotOpenedAndTearDown(epoch: 1, reason: "STALE native timeout from launch #1")

        // Give creativeQueue a chance to run the guarded call. This is a negative
        // check (the stale callback must be dropped), so the window errs long: too
        // short and a regression could slip through unobserved on a slow machine.
        let settled = expectation(description: "creativeQueue drained")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { settled.fulfill() }
        wait(for: [settled], timeout: 5.0)

        XCTAssertNotNil(mockWebViewProvider.webView, "stale-epoch callback must NOT tear down launch #2's webview")
        XCTAssertFalse(parentView.subviews.isEmpty, "stale-epoch callback must NOT detach launch #2's webview from its parent")
    }

    func testLaunchCreative_ShouldLoadCorrectURL() {
        let parentView = UIView()
        let creativeId = "testCreative"
        let expectedURL = "https://mockurl.com/creative?id=\(creativeId)"

        let loadExpectation = self.expectation(description: "WebView load is triggered")

        // Fresh state manager (not .shared — another test leaving .shared in a
        // non-.closed state would silently no-op this launch) and a timeout that
        // can't fire while we're still asserting on the loaded URL.
        let testHandler = TestWebViewHandler(
            webViewProvider: mockWebViewProvider,
            creativeUrlBuilder: MockCreativeUrlProvider(),
            stateManager: ATTNCreativeStateManager(),
            launchTimeoutInterval: Self.neverFiresTimeout
        )
        testHandler.onMakeWebView = { mockWebView in
            mockWebView.onLoad = {
                loadExpectation.fulfill()
            }
        }
        handler = testHandler
        mockWebViewProvider.webViewSetupExpectation = expectation(description: "WebView should be set up and load the URL")

        handler.launchCreative(parentView: parentView, creativeId: creativeId)

        waitForExpectations(timeout: 30.0) { error in
            XCTAssertNil(error, "WebView did not set up and load URL in time")
            let actualURL = (self.mockWebViewProvider.webView as? MockWKWebView)?.loadedURL
            XCTAssertEqual(actualURL, expectedURL, "WebView should load the correct URL")
        }
    }
}

// MARK: Mocks

/// A custom WKWebView subclass that records the URL when load(_:) is called.
class MockWKWebView: CustomWebView {
    var loadedURL: String?
    var onLoad: (() -> Void)?

    override func load(_ request: URLRequest) -> WKNavigation? {
        loadedURL = request.url?.absoluteString
        onLoad?()
        return nil
    }
}

class MockWebViewProvider: NSObject, ATTNWebViewProviding {
    var parentView: UIView?
    var skipFatigueOnCreative: Bool = false
    var triggerHandler: ATTNCreativeTriggerCompletionHandler?

    private(set) var getDomainCallCount = 0
    private(set) var getModeCallCount = 0
    private(set) var getUserIdentityCallCount = 0

    var mockDomain: String = "mock.domain.com"
    var mockMode: ATTNSDKMode = .debug
    var mockUserIdentity: ATTNUserIdentity = .init()

    var webViewSetupExpectation: XCTestExpectation?
    var webViewRemovalExpectation: XCTestExpectation?
    private var didFulfillSetup = false
    private var didFulfillRemoval = false

    private var _webView: WKWebView?
    var webViewCreationCount = 0
    var loadedURL: String?

    var webView: WKWebView? {
        didSet {
            if let webView = webView {
                webViewCreationCount += 1
                if let mockWebView = webView as? MockWKWebView {
                    self.loadedURL = mockWebView.loadedURL
                }
                DispatchQueue.main.async {
                    if self.didFulfillSetup == false {
                        self.webViewSetupExpectation?.fulfill()
                        self.didFulfillSetup = true
                    }
                }
            } else {
                DispatchQueue.main.async {
                    if self.didFulfillRemoval == false {
                        self.webViewRemovalExpectation?.fulfill()
                        self.didFulfillRemoval = true
                    }
                }
            }
        }
    }

    /// Reset the fulfillment tracking so the same mock can be reused across a
    /// second launch/close cycle in a single test.
    func resetExpectations() {
        didFulfillSetup = false
        didFulfillRemoval = false
        webViewSetupExpectation = nil
        webViewRemovalExpectation = nil
    }

    func getDomain() -> String {
        getDomainCallCount += 1
        return mockDomain
    }

    func getMode() -> ATTNSDKMode {
        getModeCallCount += 1
        return mockMode
    }

    func getUserIdentity() -> ATTNUserIdentity {
        getUserIdentityCallCount += 1
        return mockUserIdentity
    }
}

class MockCreativeUrlProvider: ATTNCreativeUrlProviding {
    var mockUrl: String = "https://mockurl.com/creative?id=default"

    func buildCompanyCreativeUrl(configuration: ATTNCreativeUrlConfig) -> String {
        return "https://mockurl.com/creative?id=\(configuration.creativeId ?? "default")"
    }
}

class TestWebViewHandler: ATTNWebViewHandler {
    var onMakeWebView: ((MockWKWebView) -> Void)?
    override func makeWebView(launchEpoch: UInt64 = 0) -> WKWebView {
        let webView = MockWKWebView(frame: .zero, configuration: WKWebViewConfiguration())
        webView.launchEpoch = launchEpoch
        onMakeWebView?(webView)
        return webView
    }
}

/// Test handler that stubs the WKNavigationDelegate.didFinish path by short-circuiting
/// the JS evaluation call. When `stubbedJSResult` is set, the didFinish call skips
/// callAsyncJavaScript and dispatches straight into the SDK's result-handling switch,
/// mirroring the production behavior (fire .notOpened, then tear down the webview).
/// Test handler that stubs the WKNavigationDelegate.didFinish path by short-circuiting
/// the JS evaluation call. When `stubbedJSResult` is set, we hand the stubbed status
/// off to the REAL production teardown path (`reportNotOpenedAndTearDown`), so the
/// JS-timeout test exercises the same code that runs in production.
class JSTimeoutStubHandler: ATTNWebViewHandler {
    var stubbedJSResult: Result<Any, Error>?

    override func makeWebView(launchEpoch: UInt64 = 0) -> WKWebView {
        let webView = MockWKWebView(frame: .zero, configuration: WKWebViewConfiguration())
        webView.launchEpoch = launchEpoch
        return webView
    }

    override func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        guard let stubbedJSResult = stubbedJSResult else {
            super.webView(webView, didFinish: navigation)
            return
        }
        let epoch = (webView as? CustomWebView)?.launchEpoch ?? 0
        guard let webViewProvider = self.webViewProvider else { return }
        guard case let .success(statusAny) = stubbedJSResult else {
            reportNotOpenedAndTearDown(epoch: epoch, reason: "test: no status returned from JS")
            return
        }
        switch statusAny as? String {
        case "SUCCESS":
            webViewProvider.triggerHandler?(ATTNCreativeTriggerStatus.opened)
        default:
            reportNotOpenedAndTearDown(epoch: epoch, reason: "test: JS iframe-detection timed out")
        }
    }
}
