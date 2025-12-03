//
//  CreativeScreen.swift
//  CreativeUITest
//
//  Created by Vladimir - Work on 2024-06-05.
//

import XCTest

struct HomePage: Page {
    private init() {}
    
    @discardableResult
    static func tapOnPushMeToCreative() -> Self.Type {
        creativeButton.tapOnElement(timeout: Timeout.max)
        return self
    }

    @discardableResult
    static func tapOnClearUser() -> Self.Type {
        clearUserButton.tapOnElement()
        return self
    }

    @discardableResult
    static func verifyPushMeToCreativeIsHittable() -> Self.Type {
        guard creativeButton.elementExists() else {
            XCTFail("Push me to Creative is not visible")
            return self
        }
        sleep(1)
        XCTAssertTrue(creativeButton.isHittable)
        return self
    }

    @discardableResult
    static func navigateToProduct() -> Self.Type {
        productTabItem.tapOnElement()
        return self
    }

    @discardableResult
    static func tapOnSwitchDomain() -> Self.Type {
        switchDomainButton.tapOnElement()
        return self
    }

    @discardableResult
    static func verifyDomainTitle(text: String) -> Self.Type {
        let domainLabel = app.staticTexts["Domain: \(text)"]

        guard domainLabel.elementExists() else {
            XCTFail("Domain label does not exists")
            return self
        }

        return self
    }
}

fileprivate extension HomePage {
    static var creativeButton: XCUIElement {
        app.buttons["Push me for Creative!"]
    }

    static var clearUserButton: XCUIElement {
        app.buttons["Push me to clear the User!"]
    }

    static var productTabItem: XCUIElement {
        app.tabBars.buttons["Product"]
    }

    static var switchDomainButton: XCUIElement {
        app.buttons["Switch Domain"]
    }
}
