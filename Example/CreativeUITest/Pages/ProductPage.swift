//
//  ProductPage.swift
//  CreativeUITest
//
//  Created by Vladimir - Work on 2024-06-05.
//

import XCTest

struct ProductPage: Page {
    private init() { }

    @discardableResult
    static func navigateToMain() -> Self.Type {
        homeTabItem.tapOnElement()
        return self
    }

    @discardableResult
    static func tapOnAddToCart() -> Self.Type {
        addToCartButton.tapOnElement()
        return self
    }
}

fileprivate extension ProductPage {
    static var addToCartButton: XCUIElement {
        app.buttons["Add To Cart"]
    }

    static var homeTabItem: XCUIElement {
        app.tabBars.buttons["Main"]
    }
}
