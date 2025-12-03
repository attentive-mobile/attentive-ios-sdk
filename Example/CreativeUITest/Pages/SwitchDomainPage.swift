//
//  SwitchDomainPage.swift
//  CreativeUITest
//
//  Created by Vladimir - Work on 2024-06-14.
//

import XCTest

struct SwitchDomainPage: Page {
    private init() { }

    @discardableResult
    static func tapOnOk() -> Self.Type {
        okButton.tapOnElement()
        return self
    }

    @discardableResult
    static func tapOnCancel() -> Self.Type {
        cancelButton.tapOnElement()
        return self
    }

    @discardableResult
    static func fillDomainInput(text: String) -> Self.Type {
        domainTextField.tapOnElement()
        domainTextField.fillTextField(text)
        return self
    }

    @discardableResult
    static func verifyIfTitleExists() -> Self.Type {
        guard title.elementExists() else {
            XCTFail("Title does not exists")
            return self
        }
        return self
    }
}

fileprivate extension SwitchDomainPage {
    static var title: XCUIElement {
        app.staticTexts["Switch Domain"]
    }

    static var domainTextField: XCUIElement {
        app.textFields["Enter the new Domain here"]
    }

    static var okButton: XCUIElement {
        app.buttons["OK"]
    }

    static var cancelButton: XCUIElement {
        app.buttons["Cancel"]
    }
}
