//
//  ATTNTestEventUtils.swift
//  attentive-ios-sdk Tests
//
//  Created by Vladimir - Work on 2024-06-04.
//

import Foundation
import XCTest
@testable import ATTNSDKFramework

struct ATTNTestEventUtils {
    static func verifyCommonQueryItems(queryItems: [String: String], userIdentity: ATTNUserIdentity, geoAdjustedDomain: String, eventType: String, metadata: [String: Any]) {
        XCTAssertEqual("modern", queryItems["tag"])
        XCTAssertEqual("mobile-app", queryItems["v"])
        XCTAssertEqual("0", queryItems["lt"])
        XCTAssertEqual(geoAdjustedDomain, queryItems["c"])
        XCTAssertEqual(eventType, queryItems["t"])
        XCTAssertEqual(userIdentity.visitorId, queryItems["u"])

        XCTAssertEqual(userIdentity.identifiers[ATTNIdentifierType.phone] as? String, metadata["phone"] as? String)
        XCTAssertEqual(userIdentity.identifiers[ATTNIdentifierType.email] as? String, metadata["email"] as? String)
        XCTAssertEqual("msdk", metadata["source"] as? String)
    }

    static func verifyProductFromItem(item: ATTNItem, product: [String: Any]) {
        XCTAssertEqual(item.productId, product["productId"] as? String)
        XCTAssertEqual(item.productVariantId, product["subProductId"] as? String)
        XCTAssertEqual(item.price.price, NSDecimalNumber(string: product["price"] as? String))
        XCTAssertEqual(item.price.currency, product["currency"] as? String)
        XCTAssertEqual(item.category, product["category"] as? String)
        XCTAssertEqual(item.productImage, product["image"] as? String)
        XCTAssertEqual(item.name, product["name"] as? String)
    }

    static func getMetadataFromUrl(url: URL) -> [String: Any]? {
        let queryItems = getQueryItemsFromUrl(url: url)
        guard let queryItemsString = queryItems["m"] else { return nil }
        let data = queryItemsString.data(using: .utf8)!
        return try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
    }

    static func getQueryItemsFromUrl(url: URL) -> [String: String] {
        var queryItemDict = [String: String]()
        if let components = URLComponents(string: url.absoluteString),
             let queryItems = components.queryItems {
            for item in queryItems {
                queryItemDict[item.name] = item.value
            }
        }
        return queryItemDict
    }

    static func buildPurchase() -> ATTNPurchaseEvent {
        let item = buildItem()
        let order = ATTNOrder(orderId: "778899")
        let cart = ATTNCart()
        cart.cartId = "789123"
        cart.cartCoupon = "someCoupon"
        let purchaseEvent = ATTNPurchaseEvent(items: [item], order: order)
        purchaseEvent.cart = cart
        return purchaseEvent
    }

    static func buildAddToCart() -> ATTNAddToCartEvent {
        let item = buildItem()
        return ATTNAddToCartEvent(items: [item])
    }

    static func buildProductView() -> ATTNProductViewEvent {
        let item = buildItem()
        return ATTNProductViewEvent(items: [item])
    }

    static func buildItem() -> ATTNItem {
        let price = ATTNPrice(price: NSDecimalNumber(string: "15.99"), currency: "USD")
        let item = ATTNItem(productId: "222", productVariantId: "55555", price: price)
        item.category = "someCategory"
        item.productImage = "someImage"
        item.name = "someName"
        return item
    }

    static func buildPurchaseWithTwoItems() -> ATTNPurchaseEvent {
        let item1 = buildItem()
        let item2 = ATTNItem(productId: "2222", productVariantId: "555552", price: ATTNPrice(price: NSDecimalNumber(string: "20.00"), currency: "USD"))
        item2.category = "someCategory2"
        item2.productImage = "someImage2"
        item2.name = "someName2"
        let order = ATTNOrder(orderId: "778899")
        let cart = ATTNCart()
        cart.cartId = "789123"
        cart.cartCoupon = "someCoupon"
        let purchaseEvent = ATTNPurchaseEvent(items: [item1, item2], order: order)
        purchaseEvent.cart = cart
        return purchaseEvent
    }

    static func buildUserIdentity() -> ATTNUserIdentity {
        return ATTNUserIdentity(identifiers: [
            ATTNIdentifierType.phone: "+14156667777",
            ATTNIdentifierType.email: "someEmail@email.com",
            ATTNIdentifierType.clientUserId: "someClientUserId",
            ATTNIdentifierType.shopifyId: "someShopifyId",
            ATTNIdentifierType.klaviyoId: "someKlaviyoId",
            ATTNIdentifierType.customIdentifiers: ["customId": "customIdValue"]
        ])
    }

    static func buildInfoEvent() -> ATTNInfoEvent {
        return ATTNInfoEvent()
    }

    static func buildCustomEvent() -> ATTNCustomEvent {
        return ATTNCustomEvent(type: "Concert Viewed", properties: ["band": "The Beatles"])!
    }
}
