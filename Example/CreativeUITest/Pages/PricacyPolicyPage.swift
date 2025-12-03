//
//  PricacyPolicyPage.swift
//  CreativeUITest
//
//  Created by Vladimir - Work on 2024-06-05.
//

import XCTest

struct PricacyPolicyPage: Page {
    private init() {}

    @discardableResult
    static func verifyContent() -> Self.Type {
        XCTAssertTrue(
            privacyPolicy.elementExists()
            || messagingPrivacyPolicy.elementExists()
        )
        return self
    }
}

fileprivate extension PricacyPolicyPage {
    static var privacyPolicy: XCUIElement {
        safariApp.staticTexts["Privacy Policy"]
    }

    static var messagingPrivacyPolicy: XCUIElement {
        safariApp.staticTexts["Messaging Privacy Policy"]
    }
}
