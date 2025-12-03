//
//  ATTNV2EventModelsTests.swift
//  attentive-ios-sdk Tests
//
//  Created by Adela Gao on 11/10/25.
//

import XCTest
@testable import ATTNSDKFramework

final class ATTNV2EventModelsTests: XCTestCase {

    // MARK: - ATTNProduct Tests

    func testATTNProduct_init_allFields_succeeds() {
        let product = ATTNProduct(
            productId: "123",
            variantId: "456",
            name: "Test Product",
            variantName: "Blue",
            imageUrl: "https://example.com/image.jpg",
            categories: ["Electronics", "Gaming"],
            price: "59.99",
            quantity: 2,
            productUrl: "https://example.com/product/123"
        )

        XCTAssertEqual(product.productId, "123")
        XCTAssertEqual(product.variantId, "456")
        XCTAssertEqual(product.name, "Test Product")
        XCTAssertEqual(product.variantName, "Blue")
        XCTAssertEqual(product.imageUrl, "https://example.com/image.jpg")
        XCTAssertEqual(product.categories, ["Electronics", "Gaming"])
        XCTAssertEqual(product.price, "59.99")
        XCTAssertEqual(product.quantity, 2)
        XCTAssertEqual(product.productUrl, "https://example.com/product/123")
    }

    func testATTNProduct_init_onlyRequiredFields_succeeds() {
        let product = ATTNProduct(
            productId: "123",
            name: "Test Product",
            price: "59.99",
            quantity: 1
        )

        XCTAssertEqual(product.productId, "123")
        XCTAssertEqual(product.name, "Test Product")
        XCTAssertEqual(product.price, "59.99")
        XCTAssertEqual(product.quantity, 1)
        XCTAssertNil(product.variantId)
        XCTAssertNil(product.variantName)
        XCTAssertNil(product.imageUrl)
        XCTAssertNil(product.categories)
        XCTAssertNil(product.productUrl)
    }

    func testATTNProduct_encode_encodesAllFields() throws {
        let product = ATTNProduct(
            productId: "123",
            variantId: "456",
            name: "Test Product",
            variantName: "Blue",
            imageUrl: "https://example.com/image.jpg",
            categories: ["Electronics"],
            price: "59.99",
            quantity: 1,
            productUrl: "https://example.com/product/123"
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(product)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        XCTAssertNotNil(json)
        XCTAssertEqual(json?["productId"] as? String, "123")
        XCTAssertEqual(json?["variantId"] as? String, "456")
        XCTAssertEqual(json?["name"] as? String, "Test Product")
        XCTAssertEqual(json?["price"] as? String, "59.99")
        XCTAssertEqual(json?["quantity"] as? Int, 1)
    }

    // MARK: - ATTNIdentifiers Tests

    func testATTNIdentifiers_init_allFields_succeeds() {
        let identifiers = ATTNIdentifiers(
            encryptedEmail: "encodedEmail",
            encryptedPhone: "encodedPhone",
            otherIdentifiers: [["idType": "ShopifyId", "value": "12345"]]
        )

        XCTAssertEqual(identifiers.encryptedEmail, "encodedEmail")
        XCTAssertEqual(identifiers.encryptedPhone, "encodedPhone")
        XCTAssertEqual(identifiers.otherIdentifiers?.count, 1)
    }

    func testATTNIdentifiers_init_nilFields_succeeds() {
        let identifiers = ATTNIdentifiers(
            encryptedEmail: nil,
            encryptedPhone: nil,
            otherIdentifiers: nil
        )

        XCTAssertNil(identifiers.encryptedEmail)
        XCTAssertNil(identifiers.encryptedPhone)
        XCTAssertNil(identifiers.otherIdentifiers)
    }

    func testATTNIdentifiers_encode_encodesAllFields() throws {
        let identifiers = ATTNIdentifiers(
            encryptedEmail: "encodedEmail",
            encryptedPhone: "encodedPhone",
            otherIdentifiers: nil
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(identifiers)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        XCTAssertNotNil(json)
        XCTAssertEqual(json?["encryptedEmail"] as? String, "encodedEmail")
        XCTAssertEqual(json?["encryptedPhone"] as? String, "encodedPhone")
    }

    // MARK: - ATTNCartPayload Tests

    func testATTNCartPayload_init_allFields_succeeds() {
        let cart = ATTNCartPayload(
            cartId: "cart123",
            cartTotal: "100.00",
            cartCoupon: "SAVE10",
            cartDiscount: "10.00"
        )

        XCTAssertEqual(cart.cartId, "cart123")
        XCTAssertEqual(cart.cartTotal, "100.00")
        XCTAssertEqual(cart.cartCoupon, "SAVE10")
        XCTAssertEqual(cart.cartDiscount, "10.00")
    }

    func testATTNCartPayload_init_nilFields_succeeds() {
        let cart = ATTNCartPayload()

        XCTAssertNil(cart.cartId)
        XCTAssertNil(cart.cartTotal)
        XCTAssertNil(cart.cartCoupon)
        XCTAssertNil(cart.cartDiscount)
    }

    func testATTNCartPayload_initFromLegacyCart_convertsCorrectly() {
        let legacyCart = ATTNCart()
        legacyCart.cartId = "cart123"
        legacyCart.cartCoupon = "SAVE10"

        let cart = ATTNCartPayload(from: legacyCart, total: "100.00", discount: "10.00")

        XCTAssertEqual(cart.cartId, "cart123")
        XCTAssertEqual(cart.cartCoupon, "SAVE10")
        XCTAssertEqual(cart.cartTotal, "100.00")
        XCTAssertEqual(cart.cartDiscount, "10.00")
    }

    // MARK: - ATTNAddToCartMetadata Tests

    func testATTNAddToCartMetadata_init_setsEventType() {
        let product = ATTNProduct(productId: "123", name: "Test", price: "10.00", quantity: 1)
        let metadata = ATTNAddToCartMetadata(product: product, currency: "USD")

        XCTAssertEqual(metadata.eventType, "AddToCart")
        XCTAssertEqual(metadata.currency, "USD")
    }

    func testATTNAddToCartMetadata_encode_includesAllFields() throws {
        let product = ATTNProduct(productId: "123", name: "Test", price: "10.00", quantity: 1)
        let metadata = ATTNAddToCartMetadata(product: product, currency: "USD")

        let encoder = JSONEncoder()
        let data = try encoder.encode(metadata)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        XCTAssertNotNil(json)
        XCTAssertEqual(json?["eventType"] as? String, "AddToCart")
        XCTAssertEqual(json?["currency"] as? String, "USD")
        XCTAssertNotNil(json?["product"])
    }

    // MARK: - ATTNProductViewMetadata Tests

    func testATTNProductViewMetadata_init_setsEventType() {
        let product = ATTNProduct(productId: "123", name: "Test", price: "10.00", quantity: 1)
        let metadata = ATTNProductViewMetadata(product: product, currency: "USD")

        XCTAssertEqual(metadata.eventType, "ProductView")
        XCTAssertEqual(metadata.currency, "USD")
    }

    // MARK: - ATTNPurchaseMetadata Tests

    func testATTNPurchaseMetadata_init_allFields_succeeds() {
        let product = ATTNProduct(productId: "123", name: "Test", price: "10.00", quantity: 1)
        let cart = ATTNCartPayload(cartId: "cart123", cartTotal: "10.00", cartCoupon: nil, cartDiscount: nil)
        let metadata = ATTNPurchaseMetadata(
            orderId: "order123",
            currency: "USD",
            orderTotal: "10.00",
            cart: cart,
            products: [product]
        )

        XCTAssertEqual(metadata.eventType, "Purchase")
        XCTAssertEqual(metadata.orderId, "order123")
        XCTAssertEqual(metadata.currency, "USD")
        XCTAssertEqual(metadata.orderTotal, "10.00")
        XCTAssertNotNil(metadata.cart)
        XCTAssertEqual(metadata.products.count, 1)
    }

    func testATTNPurchaseMetadata_encode_includesAllFields() throws {
        let product = ATTNProduct(productId: "123", name: "Test", price: "10.00", quantity: 1)
        let metadata = ATTNPurchaseMetadata(
            orderId: "order123",
            currency: "USD",
            orderTotal: "10.00",
            cart: nil,
            products: [product]
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(metadata)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        XCTAssertNotNil(json)
        XCTAssertEqual(json?["eventType"] as? String, "Purchase")
        XCTAssertEqual(json?["orderId"] as? String, "order123")
        XCTAssertEqual(json?["currency"] as? String, "USD")
        XCTAssertEqual(json?["orderTotal"] as? String, "10.00")
    }

    // MARK: - ATTNMobileCustomEventMetadata Tests

    func testATTNMobileCustomEventMetadata_init_withProperties_succeeds() {
        let properties = ["key1": "value1", "key2": "value2"]
        let metadata = ATTNMobileCustomEventMetadata(customProperties: properties)

        XCTAssertEqual(metadata.eventType, "MobileCustomEvent")
        XCTAssertEqual(metadata.customProperties?.count, 2)
        XCTAssertEqual(metadata.customProperties?["key1"], "value1")
    }

    func testATTNMobileCustomEventMetadata_init_withoutProperties_succeeds() {
        let metadata = ATTNMobileCustomEventMetadata(customProperties: nil)

        XCTAssertEqual(metadata.eventType, "MobileCustomEvent")
        XCTAssertNil(metadata.customProperties)
    }

    func testATTNMobileCustomEventMetadata_encode_includesAllFields() throws {
        let properties = ["testKey": "testValue"]
        let metadata = ATTNMobileCustomEventMetadata(customProperties: properties)

        let encoder = JSONEncoder()
        let data = try encoder.encode(metadata)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        XCTAssertNotNil(json)
        XCTAssertEqual(json?["eventType"] as? String, "MobileCustomEvent")
        let customProps = json?["customProperties"] as? [String: String]
        XCTAssertEqual(customProps?["testKey"], "testValue")
    }

    // MARK: - ATTNBaseEvent Tests

    func testATTNBaseEvent_init_withAddToCartMetadata_succeeds() {
        let product = ATTNProduct(productId: "123", name: "Test", price: "10.00", quantity: 1)
        let metadata = ATTNAddToCartMetadata(product: product, currency: "USD")
        let identifiers = ATTNIdentifiers(encryptedEmail: "test@test.com", encryptedPhone: nil, otherIdentifiers: nil)

        let event = ATTNBaseEvent(
            visitorId: "visitor123",
            version: "1.0.0",
            attentiveDomain: "test.attentivemobile.com",
            locationHref: nil,
            referrer: "",
            eventType: .addToCart,
            timestamp: "2025-11-10T12:00:00Z",
            identifiers: identifiers,
            eventMetadata: metadata,
            genericMetadata: nil,
            sourceType: "mobile",
            appSdk: "iOS"
        )

        XCTAssertEqual(event.visitorId, "visitor123")
        XCTAssertEqual(event.eventType, .addToCart)
        XCTAssertEqual(event.sourceType, "mobile")
        XCTAssertEqual(event.appSdk, "iOS")
    }

    func testATTNBaseEvent_encode_producesValidJSON() throws {
        let product = ATTNProduct(productId: "123", name: "Test", price: "10.00", quantity: 1)
        let metadata = ATTNAddToCartMetadata(product: product, currency: "USD")
        let identifiers = ATTNIdentifiers(encryptedEmail: "encodedEmail", encryptedPhone: nil, otherIdentifiers: nil)

        let event = ATTNBaseEvent(
            visitorId: "visitor123",
            version: "1.0.0",
            attentiveDomain: "test.attentivemobile.com",
            locationHref: nil,
            referrer: "",
            eventType: .addToCart,
            timestamp: "2025-11-10T12:00:00Z",
            identifiers: identifiers,
            eventMetadata: metadata,
            genericMetadata: nil,
            sourceType: "mobile",
            appSdk: "iOS"
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(event)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        XCTAssertNotNil(json)
        XCTAssertEqual(json?["visitorId"] as? String, "visitor123")
        XCTAssertEqual(json?["version"] as? String, "1.0.0")
        XCTAssertEqual(json?["eventType"] as? String, "AddToCart")
        XCTAssertEqual(json?["sourceType"] as? String, "mobile")
        XCTAssertEqual(json?["appSdk"] as? String, "iOS")
        XCTAssertNotNil(json?["identifiers"])
        XCTAssertNotNil(json?["eventMetadata"])
    }

    func testATTNBaseEvent_encodeWithCustomEvent_includesCustomProperties() throws {
        let customProps = ["prop1": "value1"]
        let metadata = ATTNMobileCustomEventMetadata(customProperties: customProps)
        let identifiers = ATTNIdentifiers(encryptedEmail: nil, encryptedPhone: nil, otherIdentifiers: nil)

        let event = ATTNBaseEvent(
            visitorId: "visitor123",
            version: "1.0.0",
            attentiveDomain: "test.attentivemobile.com",
            locationHref: nil,
            referrer: "",
            eventType: .mobileCustomEvent,
            timestamp: "2025-11-10T12:00:00Z",
            identifiers: identifiers,
            eventMetadata: metadata,
            genericMetadata: nil,
            sourceType: "mobile",
            appSdk: "iOS"
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(event)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        XCTAssertNotNil(json)
        XCTAssertEqual(json?["eventType"] as? String, "MobileCustomEvent")
        let eventMetadata = json?["eventMetadata"] as? [String: Any]
        XCTAssertNotNil(eventMetadata)
        XCTAssertEqual(eventMetadata?["eventType"] as? String, "MobileCustomEvent")
    }

    // MARK: - ATTNEventType Tests

    func testATTNEventType_rawValues_areCorrect() {
        XCTAssertEqual(ATTNEventType.purchase.rawValue, "Purchase")
        XCTAssertEqual(ATTNEventType.addToCart.rawValue, "AddToCart")
        XCTAssertEqual(ATTNEventType.productView.rawValue, "ProductView")
        XCTAssertEqual(ATTNEventType.mobileCustomEvent.rawValue, "MobileCustomEvent")
    }

    func testATTNEventType_decode_fromRawValue_succeeds() throws {
        let json = "{\"type\":\"AddToCart\"}"
        let decoder = JSONDecoder()

        struct TestContainer: Codable {
            let type: ATTNEventType
        }

        let data = json.data(using: .utf8)!
        let container = try decoder.decode(TestContainer.self, from: data)

        XCTAssertEqual(container.type, .addToCart)
    }
}
