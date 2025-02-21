//
//  ATTNWebViewHandlerUITests.swift
//  attentive-ios-sdk
//
//  Created by Bian Jiang on 2/21/25.
//

import XCTest

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
