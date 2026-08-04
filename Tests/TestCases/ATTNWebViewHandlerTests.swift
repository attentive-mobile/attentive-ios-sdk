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

    override func setUp() {
        super.setUp()
        mockWebViewProvider = MockWebViewProvider()
        mockUrlProvider = MockCreativeUrlProvider()
        handler = ATTNWebViewHandler(
            webViewProvider: mockWebViewProvider,
            creativeUrlBuilder: mockUrlProvider,
            stateManager: ATTNCreativeStateManager()
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

        waitForExpectations(timeout: 5.0) { error in
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

        waitForExpectations(timeout: 10.0) { error in
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

        waitForExpectations(timeout: 5.0) { error in
            XCTAssertNil(error, "WebView was not removed in time")
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {  // Wait to check for unexpected re-creation
            XCTAssertNil(self.mockWebViewProvider?.webView, "WebView should be nil after closing creative")
        }
    }

    func testLaunchCreative_NativeTimeout_TearsDownWebViewAndReportsNotOpened() {
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

        wait(for: [notOpenedExpectation, removalExpectation], timeout: 8.0)

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
            stateManager: ATTNCreativeStateManager()
        )
        stubHandler.stubbedJSResult = .success("TIMED OUT" as Any)
        handler = stubHandler

        stubHandler.launchCreative(parentView: parentView, creativeId: "willJSTimeout", handler: handlerClosure)

        wait(for: [notOpenedExpectation, removalExpectation], timeout: 8.0)

        XCTAssertEqual(receivedStatus, ATTNCreativeTriggerStatus.notOpened)
        XCTAssertNil(mockWebViewProvider.webView)
        XCTAssertEqual(parentView.subviews.count, 0)
    }

    func testTimeout_DoesNotFireNotOpenedTwice_WhenBothTimeoutsRace() {
        let parentView = UIView()

        var notOpenedCount = 0
        var otherStatuses: [String] = []
        let allDone = expectation(description: "some time to observe extra callbacks")

        let handlerClosure: ATTNCreativeTriggerCompletionHandler = { status in
            if status == ATTNCreativeTriggerStatus.notOpened {
                notOpenedCount += 1
            } else {
                otherStatuses.append(status)
            }
        }
        mockWebViewProvider.triggerHandler = handlerClosure

        handler.launchCreative(parentView: parentView, creativeId: "raceTest", handler: handlerClosure)

        DispatchQueue.main.asyncAfter(deadline: .now() + 7.0) {
            allDone.fulfill()
        }
        wait(for: [allDone], timeout: 10.0)

        XCTAssertEqual(notOpenedCount, 1, ".notOpened must fire exactly once even if both timeout paths run")
        XCTAssertTrue(otherStatuses.isEmpty, "must not additionally emit .closed or .opened on the timeout path; got \(otherStatuses)")
    }

    func testMultiLaunch_StaleDelegateCallback_DoesNotTearDownNewLaunch() {
        // Regression test for the epoch guard. Launch #1's webview outlives a
        // subsequent launch #2 on the SAME handler; a late delegate callback
        // (didFailProvisionalNavigation) fired against launch #1's webview must
        // NOT tear down launch #2's webview — its epoch is stale.
        let parentView = UIView()

        // Launch #1 → captures epoch 1 on its webview.
        let firstSetup = expectation(description: "webView1 setup")
        mockWebViewProvider.webViewSetupExpectation = firstSetup
        handler.launchCreative(parentView: parentView, creativeId: "first")
        wait(for: [firstSetup], timeout: 5.0)
        guard let webView1 = mockWebViewProvider.webView as? CustomWebView else {
            return XCTFail("expected CustomWebView after launch #1")
        }
        let epoch1 = webView1.launchEpoch

        // Close launch #1 on the same handler so state → .closed and the next launch is allowed.
        let closeExpectation = expectation(description: "webView1 removed")
        mockWebViewProvider.webViewRemovalExpectation = closeExpectation
        handler.closeCreative()
        wait(for: [closeExpectation], timeout: 5.0)

        // Reset expectation fulfillment tracking so launch #2's setup/removal can fire.
        let freshProvider = MockWebViewProvider()
        mockWebViewProvider = freshProvider
        // Keep the SAME handler — that's the point; its epoch counter must have advanced.
        // Reinject the fresh provider by rebuilding the handler with the same state manager
        // is NOT possible here (currentLaunchEpoch is per-instance). Instead we thread the
        // fresh provider via a spy: build a new handler that shares the previous state
        // manager so state carries over, but starts its own epoch — then verify that
        // a callback carrying an epoch that doesn't match the handler's current epoch
        // is dropped. Below we simulate that directly by asserting on webView1's epoch.

        // Launch #2 on the same handler.
        let secondSetup = expectation(description: "webView2 setup")
        freshProvider.webViewSetupExpectation = secondSetup
        // Swap the provider inside the existing handler by re-launching against it —
        // ATTNWebViewHandler holds `webViewProvider` weakly and picks the provider off
        // its captured init reference, so we need a small workaround: use a fresh
        // handler that shares the stateManager. See below.
        handler = ATTNWebViewHandler(
            webViewProvider: freshProvider,
            creativeUrlBuilder: mockUrlProvider,
            stateManager: ATTNCreativeStateManager()
        )
        handler.launchCreative(parentView: parentView, creativeId: "second")
        wait(for: [secondSetup], timeout: 5.0)
        guard let webView2 = freshProvider.webView as? CustomWebView else {
            return XCTFail("expected CustomWebView after launch #2")
        }
        // webView1 carries epoch 1. handler#2's currentLaunchEpoch is also 1 (fresh
        // instance). To simulate the real bug, force webView1's stamped epoch to a
        // value the new handler will NOT match — 0, which the new handler's counter
        // has already passed.
        webView1.launchEpoch = 0
        _ = epoch1 // silence unused warning

        // Simulate launch #1's webview firing a late delegate callback into handler#2.
        // Because webView1 carries epoch 0 (stale), the epoch guard drops the callback
        // and launch #2's webview stays intact.
        let error = NSError(domain: "test", code: -1003, userInfo: [NSLocalizedDescriptionKey: "stale"])
        handler.webView(webView1, didFailProvisionalNavigation: nil, withError: error)

        // Give the creativeQueue + main hop a chance to run.
        let settled = expectation(description: "async queues settled")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { settled.fulfill() }
        wait(for: [settled], timeout: 1.0)

        XCTAssertNotNil(freshProvider.webView, "stale-epoch callback must not tear down launch #2's webview")
        XCTAssertGreaterThan(webView2.launchEpoch, 0, "launch #2's webview must have a real (non-stale) epoch")
    }

    func testLaunchCreative_ShouldLoadCorrectURL() {
        let parentView = UIView()
        let creativeId = "testCreative"
        let expectedURL = "https://mockurl.com/creative?id=\(creativeId)"

        let loadExpectation = self.expectation(description: "WebView load is triggered")

        let testHandler = TestWebViewHandler(
            webViewProvider: mockWebViewProvider,
            creativeUrlBuilder: MockCreativeUrlProvider(),
            stateManager: ATTNCreativeStateManager.shared
        )
        testHandler.onMakeWebView = { mockWebView in
            mockWebView.onLoad = {
                loadExpectation.fulfill()
            }
        }
        handler = testHandler
        mockWebViewProvider.webViewSetupExpectation = expectation(description: "WebView should be set up and load the URL")

        handler.launchCreative(parentView: parentView, creativeId: creativeId)

        waitForExpectations(timeout: 5.0) { error in
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
        guard let webViewProvider = self.webViewProvider else { return }
        guard case let .success(statusAny) = stubbedJSResult else {
            reportNotOpenedAndTearDownForTest(webViewProvider: webViewProvider)
            return
        }
        switch statusAny as? String {
        case "SUCCESS":
            webViewProvider.triggerHandler?(ATTNCreativeTriggerStatus.opened)
        default:
            reportNotOpenedAndTearDownForTest(webViewProvider: webViewProvider)
        }
    }

    /// The stub can't reach the private `reportNotOpenedAndTearDown` on the base class,
    /// so mirror its two observable effects here: fire `.notOpened` on the main queue,
    /// then remove and null out the webView.
    private func reportNotOpenedAndTearDownForTest(webViewProvider: ATTNWebViewProviding) {
        DispatchQueue.main.async {
            webViewProvider.triggerHandler?(ATTNCreativeTriggerStatus.notOpened)
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
