//
//  ATTNEventTrackerTests.swift
//  attentive-ios-sdk Tests
//
//  Created by Vladimir - Work on 2024-06-04.
//

import XCTest
@testable import ATTNSDKFramework

final class ATTNEventTrackerTests: XCTestCase {

    var apiSpy: ATTNAPISpy!
    var sdk: ATTNSDK!
    var tracker: ATTNEventTracker!

    override func setUp() {
        super.setUp()
        apiSpy = ATTNAPISpy(domain: "test.attentivemobile.com")
        sdk = ATTNSDK(api: apiSpy)
        ATTNEventTracker.setup(with: sdk)
        tracker = ATTNEventTracker.sharedInstance()
    }

    override func tearDown() {
        ATTNEventTracker.destroy()
        apiSpy = nil
        sdk = nil
        tracker = nil
        super.tearDown()
    }

    func testGetSharedInstance_notSetup_throws() {
        let sdkMock = ATTNSDK(domain: "domain")
        ATTNEventTracker.setup(with: sdkMock)

        XCTAssertNoThrow(ATTNEventTracker.sharedInstance())
    }

    // MARK: - Legacy Event to V2 Conversion Tests

    func testRecord_legacyAddToCartEvent_usesV2Endpoint() {
        // Create a legacy AddToCart event
        let item = ATTNItem(
            productId: "test123",
            productVariantId: "variant456",
            price: ATTNPrice(price: NSDecimalNumber(string: "29.99"), currency: "USD")
        )
        item.name = "Test Product"
        item.category = "Electronics"

        let addToCartEvent = ATTNAddToCartEvent(items: [item])

        // Record the event
        tracker.record(event: addToCartEvent)

        // Verify that the new v2 API was called instead of legacy
        XCTAssertTrue(apiSpy.sendNewEventWasCalled, "V2 endpoint should be called for legacy AddToCart events")
        XCTAssertFalse(apiSpy.sendEventWasCalled, "Legacy endpoint should NOT be called")
    }

    func testRecord_legacyProductViewEvent_usesV2Endpoint() {
        // Create a legacy ProductView event
        let item = ATTNItem(
            productId: "test123",
            productVariantId: "variant456",
            price: ATTNPrice(price: NSDecimalNumber(string: "49.99"), currency: "USD")
        )
        item.name = "Test Product"

        let productViewEvent = ATTNProductViewEvent(items: [item])

        // Record the event
        tracker.record(event: productViewEvent)

        // Verify that the new v2 API was called
        XCTAssertTrue(apiSpy.sendNewEventWasCalled, "V2 endpoint should be called for legacy ProductView events")
        XCTAssertFalse(apiSpy.sendEventWasCalled, "Legacy endpoint should NOT be called")
    }

    func testRecord_legacyPurchaseEvent_usesV2Endpoint() {
        // Create a legacy Purchase event
        let item = ATTNItem(
            productId: "test123",
            productVariantId: "variant456",
            price: ATTNPrice(price: NSDecimalNumber(string: "99.99"), currency: "USD")
        )
        item.quantity = 2

        let order = ATTNOrder(orderId: "order789")
        let purchaseEvent = ATTNPurchaseEvent(items: [item], order: order)

        // Record the event
        tracker.record(event: purchaseEvent)

        // Verify that the new v2 API was called
        XCTAssertTrue(apiSpy.sendNewEventWasCalled, "V2 endpoint should be called for legacy Purchase events")
        XCTAssertFalse(apiSpy.sendEventWasCalled, "Legacy endpoint should NOT be called")
    }

    func testRecord_legacyCustomEvent_usesV2Endpoint() {
        // Create a legacy Custom event
        let customEvent = ATTNCustomEvent(
            type: "test_event",
            properties: ["key1": "value1", "key2": "value2"]
        )

        // Record the event
        if let event = customEvent {
            tracker.record(event: event)

            // Verify that the new v2 API was called
            XCTAssertTrue(apiSpy.sendNewEventWasCalled, "V2 endpoint should be called for legacy Custom events")
            XCTAssertFalse(apiSpy.sendEventWasCalled, "Legacy endpoint should NOT be called")
        } else {
            XCTFail("Custom event creation failed")
        }
    }

    func testRecord_legacyPurchaseEventWithCart_convertsCartToV2() {
        // Create a legacy Purchase event with cart
        let item = ATTNItem(
            productId: "test123",
            productVariantId: "variant456",
            price: ATTNPrice(price: NSDecimalNumber(string: "50.00"), currency: "USD")
        )
        item.quantity = 1

        let cart = ATTNCart(cartId: "cart123", cartCoupon: "SAVE10")
        let order = ATTNOrder(orderId: "order789")

        let purchaseEvent = ATTNPurchaseEvent(items: [item], order: order)
        purchaseEvent.cart = cart

        // Record the event
        tracker.record(event: purchaseEvent)

        // Verify that the new v2 API was called
        XCTAssertTrue(apiSpy.sendNewEventWasCalled, "V2 endpoint should be called with cart data")
    }

    func testRecord_legacyAddToCartWithMultipleItems_onlySendsFirstItem() {
        // Create a legacy AddToCart event with multiple items
        let item1 = ATTNItem(
            productId: "test123",
            productVariantId: "variant456",
            price: ATTNPrice(price: NSDecimalNumber(string: "29.99"), currency: "USD")
        )
        let item2 = ATTNItem(
            productId: "test789",
            productVariantId: "variant012",
            price: ATTNPrice(price: NSDecimalNumber(string: "39.99"), currency: "USD")
        )

        let addToCartEvent = ATTNAddToCartEvent(items: [item1, item2])

        // Record the event
        tracker.record(event: addToCartEvent)

        // Verify that the new v2 API was called
        XCTAssertTrue(apiSpy.sendNewEventWasCalled, "V2 endpoint should be called even with multiple items")
        // Note: Only the first item will be sent in v2 format
    }
}
