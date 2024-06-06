//
//  XCUIElement+Extension.swift
//  CreativeUITest
//
//  Created by Vladimir - Work on 2024-06-05.
//

import XCTest

extension XCUIElement {
  /// Verify element existence and then proceed with tapping on it
  func tapOnElement() {
    guard elementExists() else {
      XCTFail("\(description) does not exists")
      return
    }
    tap()
  }

  /// Verify element existence on the app view hierarchy
  func elementExists() -> Bool {
    elementExists(timeout: 10)
  }

  func fillTextField(_ text: String) {
    guard elementExists() else {
      XCTFail("\(description) does not exists")
      return
    }

    typeText(text)
  }
}

fileprivate extension XCUIElement {
  func elementExists(timeout: TimeInterval) -> Bool {
    waitForExistence(timeout: timeout)
  }
}