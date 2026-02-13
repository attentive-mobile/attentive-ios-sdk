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
    override func makeWebView() -> WKWebView {
        let webView = MockWKWebView(frame: .zero, configuration: WKWebViewConfiguration())
        onMakeWebView?(webView)
        return webView
    }
}
