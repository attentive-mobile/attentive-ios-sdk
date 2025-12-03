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
    closeButton.tapOnElement(timeout: Timeout.max)
    return self
  }

  @discardableResult
  static func fillEmailInput(text: String) -> Self.Type {
    emailTextField.tapOnElement(timeout: Timeout.max)
    emailTextField.fillTextField(text)
    return self
  }

  @discardableResult
  static func tapOnContinue() -> Self.Type {
    if continueButton.elementExists() {
      continueButton.tapOnElement()
    } else {
      let goKeyboardButton = app.keyboards.buttons["go"]
      goKeyboardButton.tapOnElement(timeout: 5)
    }
    
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
    XCTAssertTrue(privacyLink.elementExists(timeout: Timeout.max))
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
      let searchText = "Privacy"
      let predicate = NSPredicate(format: "label CONTAINS[c] %@", searchText)
      return app.webViews.links.containing(predicate).firstMatch
  }

  static var debugStaticText: XCUIElement {
    app.staticTexts["Debug output JSON"]
  }
}
