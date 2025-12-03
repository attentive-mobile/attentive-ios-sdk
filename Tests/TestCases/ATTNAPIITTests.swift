//
//  ATTNAPIITTests.swift
//  attentive-ios-sdk Tests
//
//  Created by Vladimir - Work on 2024-06-05.
//

import XCTest
@testable import ATTNSDKFramework

final class ATTNAPIITTests: XCTestCase {

    private let testDomain = "mobileapps"
    // Update this accordingly when running on VPN
    private let testGeoAdjustedDomain = "mobileapps"
    private let eventSendTimeoutSec = 6

    var api: ATTNAPI!
    var userIdentity: ATTNUserIdentity!

    override func setUp() {
        super.setUp()
        api = ATTNAPI(domain: testDomain)
        userIdentity = ATTNTestEventUtils.buildUserIdentity()
    }

    override func tearDown() {
        api = nil
        userIdentity = nil
        super.tearDown()
    }

    func testSendUserIdentity_validIdentifiers_sendsUserIdentifierCollectedEvent() {
        // Arrange
        let eventTaskExpectation = expectation(description: "sendEventTask")
        var urlResponse: URLResponse?
        var eventUrl: URL?

        // Act
        api.send(userIdentity: userIdentity) { data, url, response, error in
            if let url = url, url.absoluteString.contains("t=idn") {
                urlResponse = response
                eventUrl = url
                eventTaskExpectation.fulfill()
            }
        }
        waitForExpectations(timeout: TimeInterval(eventSendTimeoutSec), handler: nil)

        // Assert
        if let httpResponse = urlResponse as? HTTPURLResponse {
            XCTAssertEqual(204, httpResponse.statusCode)
        } else {
            XCTFail("Response was not an HTTPURLResponse")
        }

        guard let eventUrl = eventUrl else {
            XCTFail("Event URL is nil")
            return
        }

        let queryItems = ATTNTestEventUtils.getQueryItemsFromUrl(url: eventUrl)
        let queryItemsString = queryItems["m"]
        guard let queryItemsData = queryItemsString?.data(using: .utf8),
                    let metadata = try? JSONSerialization.jsonObject(with: queryItemsData, options: []) as? [String: Any] else {
            XCTFail("Failed to parse metadata from query items")
            return
        }

        ATTNTestEventUtils.verifyCommonQueryItems(queryItems: queryItems, userIdentity: userIdentity, geoAdjustedDomain: testGeoAdjustedDomain, eventType: "idn", metadata: metadata)

        let expectedJSONString = "[{\"vendor\":\"2\",\"id\":\"someClientUserId\"},{\"vendor\":\"1\",\"id\":\"someKlaviyoId\"},{\"vendor\":\"0\",\"id\":\"someShopifyId\"},{\"vendor\":\"6\",\"id\":\"customIdValue\",\"name\":\"customId\"}]"
        guard let expectedData = expectedJSONString.data(using: .utf8),
                    let expectedDictionary = try? JSONSerialization.jsonObject(with: expectedData, options: []) as? [[String: String]] else {
            XCTFail("Failed to parse expected JSON string")
            return
        }

        let actualJSONString = queryItems["evs"]
        guard let actualData = actualJSONString?.data(using: .utf8),
                    let actualDictionary = try? JSONSerialization.jsonObject(with: actualData, options: []) as? [[String: String]] else {
            XCTFail("Failed to parse actual JSON string")
            return
        }

        XCTAssertEqual(expectedDictionary, actualDictionary)
        XCTAssertEqual("idn", queryItems["t"])
    }

    func testSendEvent_validPurchaseEvent_sendsPurchaseAndOrderConfirmedEvents() {
        // Arrange
        let purchase = ATTNTestEventUtils.buildPurchase()

        let purchaseTaskExpectation = expectation(description: "purchaseTask")
        var purchaseUrlResponse: URLResponse?
        var purchaseUrl: URL?

        let ocTaskExpectation = expectation(description: "ocTask")
        var ocUrlResponse: URLResponse?
        var ocUrl: URL?

        // Act
        api.send(event: purchase, userIdentity: userIdentity) { data, url, response, error in
            if let url = url {
                if url.absoluteString.contains("t=p") {
                    purchaseUrlResponse = response
                    purchaseUrl = url
                    purchaseTaskExpectation.fulfill()
                } else {
                    ocUrlResponse = response
                    ocUrl = url
                    ocTaskExpectation.fulfill()
                }
            }
        }
        waitForExpectations(timeout: TimeInterval(eventSendTimeoutSec), handler: nil)

        // Assert

        // Purchase Event
        if let httpResponse = purchaseUrlResponse as? HTTPURLResponse {
            XCTAssertEqual(204, httpResponse.statusCode)
        } else {
            XCTFail("Purchase response was not an HTTPURLResponse")
        }

        guard let purchaseUrl = purchaseUrl else {
            XCTFail("Purchase URL is nil")
            return
        }

        let purchaseQueryItems = ATTNTestEventUtils.getQueryItemsFromUrl(url: purchaseUrl)
        let purchaseQueryItemsString = purchaseQueryItems["m"]
        guard let purchaseQueryItemsData = purchaseQueryItemsString?.data(using: .utf8),
                    let purchaseMetadata = try? JSONSerialization.jsonObject(with: purchaseQueryItemsData, options: []) as? [String: Any] else {
            XCTFail("Failed to parse purchase metadata from query items")
            return
        }

        ATTNTestEventUtils.verifyCommonQueryItems(queryItems: purchaseQueryItems, userIdentity: userIdentity, geoAdjustedDomain: testGeoAdjustedDomain, eventType: "p", metadata: purchaseMetadata)

        XCTAssertEqual(purchase.items[0].productId, purchaseMetadata["productId"] as? String)
        XCTAssertEqual(purchase.items[0].productVariantId, purchaseMetadata["subProductId"] as? String)
        XCTAssertEqual(purchase.items[0].price.price, NSDecimalNumber(string: purchaseMetadata["price"] as? String))
        XCTAssertEqual(purchase.items[0].price.currency, purchaseMetadata["currency"] as? String)
        XCTAssertEqual(purchase.items[0].category, purchaseMetadata["category"] as? String)
        XCTAssertEqual(purchase.items[0].productImage, purchaseMetadata["image"] as? String)
        XCTAssertEqual(purchase.items[0].name, purchaseMetadata["name"] as? String)

        let quantity = String(purchase.items[0].quantity)
        XCTAssertEqual(quantity, purchaseMetadata["quantity"] as? String)
        XCTAssertEqual(purchase.order.orderId, purchaseMetadata["orderId"] as? String)
        XCTAssertEqual(purchase.cart?.cartId, purchaseMetadata["cartId"] as? String)
        XCTAssertEqual(purchase.cart?.cartCoupon, purchaseMetadata["cartCoupon"] as? String)

        // Order Confirmed Event
        if let httpResponse = ocUrlResponse as? HTTPURLResponse {
            XCTAssertEqual(204, httpResponse.statusCode)
        } else {
            XCTFail("Order confirmed response was not an HTTPURLResponse")
        }

        guard let ocUrl = ocUrl else {
            XCTFail("Order confirmed URL is nil")
            return
        }

        let ocQueryItems = ATTNTestEventUtils.getQueryItemsFromUrl(url: ocUrl)
        let ocMetadata = ATTNTestEventUtils.getMetadataFromUrl(url: ocUrl) as! [String : String]
        guard let productsData = ocMetadata["products"]?.data(using: .utf8),
                    let products = try? JSONSerialization.jsonObject(with: productsData, options: []) as? [[String: Any]] else {
            XCTFail("Failed to parse products from order confirmed metadata")
            return
        }
        XCTAssertEqual(1, products.count)

        ATTNTestEventUtils.verifyCommonQueryItems(queryItems: ocQueryItems, userIdentity: userIdentity, geoAdjustedDomain: testGeoAdjustedDomain, eventType: "oc", metadata: ocMetadata)

        ATTNTestEventUtils.verifyProductFromItem(item: purchase.items[0], product: products[0])

        XCTAssertEqual(purchase.order.orderId, ocMetadata["orderId"])
        XCTAssertEqual("15.99", ocMetadata["cartTotal"])
        XCTAssertEqual(purchase.items[0].price.currency, ocMetadata["currency"])
    }

    func testSendEvent_validAddToCartEvent_sendsAddToCartEvent() {
        // Arrange
        let addToCart = ATTNTestEventUtils.buildAddToCart()

        let eventTaskExpectation = expectation(description: "sendEventTask")
        var urlResponse: URLResponse?
        var eventUrl: URL?

        // Act
        api?.send(event: addToCart, userIdentity: userIdentity) { data, url, response, error in
            if let url = url, url.absoluteString.contains("t=c") {
                urlResponse = response
                eventUrl = url
                eventTaskExpectation.fulfill()
            }
        }
        waitForExpectations(timeout: TimeInterval(eventSendTimeoutSec), handler: nil)

        // Assert
        if let httpResponse = urlResponse as? HTTPURLResponse {
            XCTAssertEqual(204, httpResponse.statusCode)
        } else {
            XCTFail("Response was not an HTTPURLResponse")
        }

        guard let eventUrl = eventUrl else {
            XCTFail("Event URL is nil")
            return
        }

        let queryItems = ATTNTestEventUtils.getQueryItemsFromUrl(url: eventUrl)
        let queryItemsString = queryItems["m"]
        guard let queryItemsData = queryItemsString?.data(using: .utf8),
                    let metadata = try? JSONSerialization.jsonObject(with: queryItemsData, options: []) as? [String: Any] else {
            XCTFail("Failed to parse metadata from query items")
            return
        }

        ATTNTestEventUtils.verifyCommonQueryItems(queryItems: queryItems, userIdentity: userIdentity, geoAdjustedDomain: testGeoAdjustedDomain, eventType: "c", metadata: metadata)

        XCTAssertEqual(addToCart.items[0].productId, metadata["productId"] as? String)
        XCTAssertEqual(addToCart.items[0].productVariantId, metadata["subProductId"] as? String)
        XCTAssertEqual(addToCart.items[0].price.price, NSDecimalNumber(string: metadata["price"] as? String))
        XCTAssertEqual(addToCart.items[0].price.currency, metadata["currency"] as? String)
        XCTAssertEqual(addToCart.items[0].category, metadata["category"] as? String)
        XCTAssertEqual(addToCart.items[0].productImage, metadata["image"] as? String)
        XCTAssertEqual(addToCart.items[0].name, metadata["name"] as? String)

        let quantity = String(addToCart.items[0].quantity)
        XCTAssertEqual(quantity, metadata["quantity"] as? String)
    }

    func testSendEvent_validProductViewEvent_sendsProductViewEvent() {
        // Arrange
        let productView = ATTNTestEventUtils.buildProductView()

        let eventTaskExpectation = expectation(description: "sendEventTask")
        var urlResponse: URLResponse?
        var eventUrl: URL?

        // Act
        api?.send(event: productView, userIdentity: userIdentity) { data, url, response, error in
            if let url = url, url.absoluteString.contains("t=d") {
                urlResponse = response
                eventUrl = url
                eventTaskExpectation.fulfill()
            }
        }
        waitForExpectations(timeout: TimeInterval(eventSendTimeoutSec), handler: nil)

        // Assert
        if let httpResponse = urlResponse as? HTTPURLResponse {
            XCTAssertEqual(204, httpResponse.statusCode)
        } else {
            XCTFail("Response was not an HTTPURLResponse")
        }

        guard let eventUrl = eventUrl else {
            XCTFail("Event URL is nil")
            return
        }

        let queryItems = ATTNTestEventUtils.getQueryItemsFromUrl(url: eventUrl)
        let queryItemsString = queryItems["m"]
        guard let queryItemsData = queryItemsString?.data(using: .utf8),
                    let metadata = try? JSONSerialization.jsonObject(with: queryItemsData, options: []) as? [String: Any] else {
            XCTFail("Failed to parse metadata from query items")
            return
        }

        ATTNTestEventUtils.verifyCommonQueryItems(queryItems: queryItems, userIdentity: userIdentity, geoAdjustedDomain: testGeoAdjustedDomain, eventType: "d", metadata: metadata)

        XCTAssertEqual(productView.items[0].productId, metadata["productId"] as? String)
        XCTAssertEqual(productView.items[0].productVariantId, metadata["subProductId"] as? String)
        XCTAssertEqual(productView.items[0].price.price, NSDecimalNumber(string: metadata["price"] as? String))
        XCTAssertEqual(productView.items[0].price.currency, metadata["currency"] as? String)
        XCTAssertEqual(productView.items[0].category, metadata["category"] as? String)
        XCTAssertEqual(productView.items[0].productImage, metadata["image"] as? String)
        XCTAssertEqual(productView.items[0].name, metadata["name"] as? String)

        let quantity = String(productView.items[0].quantity)
        XCTAssertEqual(quantity, metadata["quantity"] as? String)
    }

    func testSendEvent_validCustomEvent_sendsCustomEvent() {
        // Arrange
        let customEvent = ATTNTestEventUtils.buildCustomEvent()

        let eventTaskExpectation = expectation(description: "sendEventTask")
        var urlResponse: URLResponse?
        var eventUrl: URL?

        // Act
        api?.send(event: customEvent, userIdentity: userIdentity) { data, url, response, error in
            if let url = url, url.absoluteString.contains("t=ce") {
                urlResponse = response
                eventUrl = url
                eventTaskExpectation.fulfill()
            }
        }
        waitForExpectations(timeout: TimeInterval(eventSendTimeoutSec), handler: nil)

        // Assert
        if let httpResponse = urlResponse as? HTTPURLResponse {
            XCTAssertEqual(204, httpResponse.statusCode)
        } else {
            XCTFail("Response was not an HTTPURLResponse")
        }

        guard let eventUrl = eventUrl else {
            XCTFail("Event URL is nil")
            return
        }

        let queryItems = ATTNTestEventUtils.getQueryItemsFromUrl(url: eventUrl)
        let queryItemsString = queryItems["m"]
        guard let queryItemsData = queryItemsString?.data(using: .utf8),
                    let metadata = try? JSONSerialization.jsonObject(with: queryItemsData, options: []) as? [String: Any] else {
            XCTFail("Failed to parse metadata from query items")
            return
        }

        ATTNTestEventUtils.verifyCommonQueryItems(queryItems: queryItems, userIdentity: userIdentity, geoAdjustedDomain: testGeoAdjustedDomain, eventType: "ce", metadata: metadata)

        XCTAssertEqual(customEvent.type, metadata["type"] as? String)
        if let propertiesString = metadata["properties"] as? String,
             let propertiesData = propertiesString.data(using: .utf8),
             let properties = try? JSONSerialization.jsonObject(with: propertiesData, options: []) as? [String: String] {
            XCTAssertEqual(customEvent.properties, properties)
        } else {
            XCTFail("Failed to parse properties from metadata")
        }
    }
}
