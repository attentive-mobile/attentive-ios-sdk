//
//  ATTNPriceTests.swift
//  attentive-ios-sdk Tests
//
//  Created by Umair Sharif on 2026-08-21.
//

import XCTest
@testable import ATTNSDKFramework

final class ATTNPriceTests: XCTestCase {
    func testInitWithAmount_StoresAmountAndCurrency() {
        let price = ATTNPrice(amount: NSDecimalNumber(string: "15.99"), currency: "USD")
        XCTAssertEqual(price.amount, NSDecimalNumber(string: "15.99"))
        XCTAssertEqual(price.currency, "USD")
    }

    @available(*, deprecated, message: "Exercises the deprecated `price` accessor on purpose.")
    func testDeprecatedPriceAccessor_ReturnsAmount() {
        let price = ATTNPrice(amount: NSDecimalNumber(string: "15.99"), currency: "USD")
        XCTAssertEqual(price.price, price.amount)
    }

    @available(*, deprecated, message: "Exercises the deprecated `init(price:currency:)` on purpose.")
    func testDeprecatedInitWithPrice_BehavesIdenticallyToInitWithAmount() {
        let legacy = ATTNPrice(price: NSDecimalNumber(string: "15.99"), currency: "USD")
        let current = ATTNPrice(amount: NSDecimalNumber(string: "15.99"), currency: "USD")
        XCTAssertEqual(legacy.amount, current.amount)
        XCTAssertEqual(legacy.price, current.amount)
        XCTAssertEqual(legacy.currency, current.currency)
    }

    func testObjcBridge_ExposesNewAndDeprecatedSelectors() {
        XCTAssertTrue(ATTNPrice.instancesRespond(to: NSSelectorFromString("initWithAmount:currency:")))
        XCTAssertTrue(ATTNPrice.instancesRespond(to: NSSelectorFromString("initWithPrice:currency:")))
        XCTAssertTrue(ATTNPrice.instancesRespond(to: NSSelectorFromString("amount")))
        XCTAssertTrue(ATTNPrice.instancesRespond(to: NSSelectorFromString("price")))
        XCTAssertTrue(ATTNPrice.instancesRespond(to: NSSelectorFromString("currency")))
    }

    func testObjcBridge_DeprecatedInitViaSelector_ProducesSameAmount() throws {
        // Simulates an ObjC consumer still calling [[ATTNPrice alloc] initWithPrice:currency:].
        // Ownership: `alloc` returns +1, which `init...` consumes and returns as its own +1;
        // that single ownership is claimed exactly once, by takeRetainedValue() on the init
        // result. The alloc result stays Unmanaged so ARC never double-claims it.
        let allocated = try XCTUnwrap(
            (ATTNPrice.self as AnyObject).perform(NSSelectorFromString("alloc"))
        )
        let initialized = allocated.takeUnretainedValue().perform(
            NSSelectorFromString("initWithPrice:currency:"),
            with: NSDecimalNumber(string: "9.99"),
            with: "USD"
        )
        let price = try XCTUnwrap(initialized?.takeRetainedValue() as? ATTNPrice)
        XCTAssertEqual(price.amount, NSDecimalNumber(string: "9.99"))
        XCTAssertEqual(price.currency, "USD")
    }
}
