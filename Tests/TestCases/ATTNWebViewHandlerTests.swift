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
    handler = ATTNWebViewHandler(webViewProvider: mockWebViewProvider, creativeUrlBuilder: mockUrlProvider)
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

  func testLaunchCreative_ShouldPreventRaceConditions() {
    let parentView = UIView()
    let expectation = self.expectation(description: "WebView should be set")

    expectation.expectedFulfillmentCount = 1 // Only one WebView should be created

    mockWebViewProvider.webViewSetupExpectation = expectation

    DispatchQueue.global().async {
      print("Dispatch 1 - Launching creative 1")
      self.handler.launchCreative(parentView: parentView, creativeId: "raceCondition1")
    }

    DispatchQueue.global().async {
      print("Dispatch 2 - Launching creative 2")
      self.handler.launchCreative(parentView: parentView, creativeId: "raceCondition2")
    }

    waitForExpectations(timeout: 5.0) { error in
      if let error = error {
        print("Expectation not fulfilled: \(error.localizedDescription)")
      }
      XCTAssertNil(error, "Race condition was not handled correctly")
    }

    print("WebView creation count: \(mockWebViewProvider.webViewCreationCount)")
    XCTAssertEqual(mockWebViewProvider.webViewCreationCount, 1, "WebView should be created only once")
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
      XCTAssertNil(self.mockWebViewProvider.webView, "WebView should be nil after closing creative")
    }
  }

  func testLaunchCreative_ShouldLoadCorrectURL() {
    let parentView = UIView()
    let creativeId = "testCreative"

    print("TEST: Launching creative with ID \(creativeId)...")
    handler.launchCreative(parentView: parentView, creativeId: creativeId)

    // Allow some time for URL to be set
    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
      print("TEST: Expected URL: https://mockurl.com/creative?id=\(creativeId)")
      print("TEST: Actual URL: \(self.mockWebViewProvider.loadedURL ?? "nil")")

      XCTAssertEqual(
        self.mockWebViewProvider.loadedURL,
        "https://mockurl.com/creative?id=\(creativeId)",
        "WebView should load the correct URL"
      )
    }
  }
}

// MARK: UI tests

final class ATTNWebViewHandlerUITests: XCTestCase {

  let app = XCUIApplication()

  override func setUp() {
    super.setUp()
    continueAfterFailure = false
    app.launch()
  }

  override func tearDown() {
    super.tearDown()
  }

  func testLaunchCreative_ShowsWebView() {
    let launchButton = app.buttons["LaunchCreativeButton"]
    XCTAssertTrue(launchButton.exists, "Launch button should exist")

    // Tap to trigger creative launch
    launchButton.tap()

    // Check that WKWebView appears
    let webView = app.webViews.firstMatch
    XCTAssertTrue(webView.waitForExistence(timeout: 5), "WebView should be visible after launching creative")
  }

  func testLaunchCreative_DoesNotDuplicateWebView() {
    let launchButton = app.buttons["LaunchCreativeButton"]
    launchButton.tap()

    let webView = app.webViews.firstMatch
    XCTAssertTrue(webView.waitForExistence(timeout: 5), "WebView should be visible after first launch")

    // Tap the button again to simulate a rapid double-tap
    launchButton.tap()

    // Ensure there's still only one WebView
    XCTAssertEqual(app.webViews.count, 1, "There should be only one WebView instance")
  }

  func testCloseCreative_HidesWebView() {
    let launchButton = app.buttons["LaunchCreativeButton"]
    let closeButton = app.buttons["CloseCreativeButton"]

    launchButton.tap()

    let webView = app.webViews.firstMatch
    XCTAssertTrue(webView.waitForExistence(timeout: 5), "WebView should be visible after launching creative")

    closeButton.tap()

    XCTAssertFalse(webView.exists, "WebView should be removed after closing creative")
  }

  func testLaunchCreative_DoesNotCrashDueToThreadingIssues() {
    let launchButton = app.buttons["LaunchCreativeButton"]

    for _ in 0..<10 {
      launchButton.tap() // Tap multiple times to simulate stress
    }

    let webView = app.webViews.firstMatch
    XCTAssertTrue(webView.waitForExistence(timeout: 5), "WebView should be visible")

    XCTAssertNoThrow(launchButton.tap(), "Repeated UI interactions should not cause a crash")
  }
}

// MARK: Mocks

class MockWebViewProvider: NSObject, ATTNWebViewProviding {
  var parentView: UIView?
  var skipFatigueOnCreative: Bool = false
  var triggerHandler: ATTNCreativeTriggerCompletionHandler?
  var isCreativeOpen: Bool = false

  private(set) var getDomainCallCount = 0
  private(set) var getModeCallCount = 0
  private(set) var getUserIdentityCallCount = 0

  var mockDomain: String = "mock.domain.com"
  var mockMode: ATTNSDKMode = .debug
  var mockUserIdentity: ATTNUserIdentity = .init()

  // XCTestExpectations for async behavior
  var webViewSetupExpectation: XCTestExpectation?
  var webViewRemovalExpectation: XCTestExpectation?

  private var _webView: WKWebView?
  var webViewCreationCount = 0
  var loadedURL: String?

  // Observers to trigger expectations
  var webView: WKWebView? {
    didSet {
      if let _ = webView {
        webViewCreationCount += 1
        print("MockWebViewProvider: WebView created, count: \(webViewCreationCount)")
        DispatchQueue.main.async {
          self.webViewSetupExpectation?.fulfill()
        }
      } else {
        print("MockWebViewProvider: WebView removed")
        DispatchQueue.main.async {
          self.webViewRemovalExpectation?.fulfill()
        }
      }
    }
  }

  func getDomain() -> String {
    return "mock.domain.com"
  }

  func getMode() -> ATTNSDKMode {
    return .debug
  }

  func getUserIdentity() -> ATTNUserIdentity {
    return .init()
  }
}

class MockCreativeUrlProvider: ATTNCreativeUrlProviding {
  var mockUrl: String = "https://mockurl.com/creative?id=default"

  func buildCompanyCreativeUrl(configuration: ATTNCreativeUrlConfig) -> String {
    return "https://mockurl.com/creative?id=\(configuration.creativeId ?? "default")"
  }
}


