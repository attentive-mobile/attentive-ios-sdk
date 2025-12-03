//
//  Page.swift
//  CreativeUITest
//
//  Created by Vladimir - Work on 2024-06-05.
//

import XCTest

protocol Page { }

extension Page {
    static var app: XCUIApplication {
        .init()
    }

    static var safariApp: XCUIApplication {
        .init(bundleIdentifier: "com.apple.mobilesafari")
    }

    static var smsApp: XCUIApplication {
        .init(bundleIdentifier: "com.apple.MobileSMS")
    }

    @discardableResult
    static func addDelay(seconds delay: Int = 2) -> Self.Type {
        sleep(UInt32(delay))
        return self
    }

    @discardableResult
    static func dismissKeyboard() -> Self.Type {
        let window = app.windows.element(boundBy: 0)
            .coordinate(
                withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)
            )
        window.tap()
        return self
    }

    @discardableResult
    static func verifyIfElementExists(label: String, elementType: XCUIElement.ElementType) -> Self.Type {
        let element = app.descendants(matching: elementType)[label]

        guard element.elementExists() else {
            XCTFail("Element with label \(label) of type \(elementType) does not exists")
            return self
        }

        return self
    }
}
