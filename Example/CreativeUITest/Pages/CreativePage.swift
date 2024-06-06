//
//  CreativePage.swift
//  CreativeUITest
//
//  Created by Vladimir - Work on 2024-06-05.
//

import XCTest

struct CreativePage: Page {
  private init() { }

  @discardableResult
  static func tapOnCloseCreative() -> Self.Type {
    closeButton.tapOnElement()
    return self
  }

  @discardableResult
  static func fillEmailInput(text: String) -> Self.Type {
    emailTextField.tapOnElement()
    emailTextField.fillTextField(text)
    return self
  }

  @discardableResult
  static func tapOnContinue() -> Self.Type {
    continueButton.tapOnElement()
    return self
  }

  @discardableResult
  static func tapOnSubscribe() -> Self.Type {
    subscribeButton.tapOnElement()
    return self
  }

  @discardableResult
  static func tapOnPrivacyLink() -> Self.Type {
    privacyLink.tapOnElement()
    return self
  }

  @discardableResult
  static func verifyDebugPage() -> Self.Type {
    XCTAssertTrue(debugStaticText.elementExists())
    return self
  }

  @discardableResult
  static func verifyPrivacyLinkExists() -> Self.Type {
    XCTAssertTrue(privacyLink.elementExists())
    return self
  }
}

fileprivate extension CreativePage {
  static var closeButton: XCUIElement {
    app.webViews.buttons["Dismiss this popup"]
  }

  static var emailTextField: XCUIElement {
    app.webViews.textFields["Email Address"]
  }

  static var continueButton: XCUIElement {
    app.webViews.buttons["CONTINUE"]
  }

  static var subscribeButton: XCUIElement {
    app.webViews.buttons["GET 10% OFF NOW when you sign up for email and texts"]
  }

  static var privacyLink: XCUIElement {
    app.webViews.links["Privacy"]
  }

  static var debugStaticText: XCUIElement {
    app.staticTexts["Debug output JSON"]
  }
}