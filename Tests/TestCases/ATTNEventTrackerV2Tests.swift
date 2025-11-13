//
//  ATTNEventTrackerV2Tests.swift
//  attentive-ios-sdk Tests
//
//  Created by Adela Gao on 11/10/25.
//

import XCTest
@testable import ATTNSDKFramework

final class ATTNEventTrackerV2Tests: XCTestCase {

  var tracker: ATTNEventTracker!
  var sdk: ATTNSDK!

  override func setUp() {
    super.setUp()
    sdk = ATTNSDK(domain: "test.attentivemobile.com")
    ATTNEventTracker.setup(with: sdk)
    tracker = ATTNEventTracker.sharedInstance()
  }

  override func tearDown() {
    ATTNEventTracker.destroy()
    tracker = nil
    sdk = nil
    super.tearDown()
  }

  // MARK: - Setup Tests

  func testSharedInstance_afterSetup_returnsValidInstance() {
    XCTAssertNotNil(ATTNEventTracker.sharedInstance())
  }

  // MARK: - AddToCart Event Tests

  func testRecordEvent_addToCart_withRequiredFields_doesNotThrow() {
    let product = ATTNProduct(
      productId: "123",
      name: "Test Product",
      price: "59.99",
      quantity: 1
    )

    XCTAssertNoThrow(tracker.recordEvent(.addToCart(product: product, currency: "USD")))
  }

  func testRecordEvent_addToCart_withAllFields_doesNotThrow() {
    let product = ATTNProduct(
      productId: "123",
      variantId: "456",
      name: "Test Product",
      variantName: "Blue Edition",
      imageUrl: "https://example.com/image.jpg",
      categories: ["Electronics", "Gaming"],
      price: "59.99",
      quantity: 2,
      productUrl: "https://example.com/product/123"
    )

    XCTAssertNoThrow(tracker.recordEvent(.addToCart(product: product, currency: "USD")))
  }

  func testRecordEvent_addToCart_differentCurrencies_doesNotThrow() {
    let product = ATTNProduct(productId: "123", name: "Test", price: "10.00", quantity: 1)

    XCTAssertNoThrow(tracker.recordEvent(.addToCart(product: product, currency: "USD")))
    XCTAssertNoThrow(tracker.recordEvent(.addToCart(product: product, currency: "EUR")))
    XCTAssertNoThrow(tracker.recordEvent(.addToCart(product: product, currency: "GBP")))
  }

  // MARK: - ProductView Event Tests

  func testRecordEvent_productView_withRequiredFields_doesNotThrow() {
    let product = ATTNProduct(
      productId: "123",
      name: "Test Product",
      price: "59.99",
      quantity: 1
    )

    XCTAssertNoThrow(tracker.recordEvent(.productView(product: product, currency: "USD")))
  }

  func testRecordEvent_productView_withAllFields_doesNotThrow() {
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

    XCTAssertNoThrow(tracker.recordEvent(.productView(product: product, currency: "USD")))
  }

  // MARK: - Purchase Event Tests

  func testRecordEvent_purchase_withoutCart_doesNotThrow() {
    let product = ATTNProduct(productId: "123", name: "Test", price: "10.00", quantity: 1)

    XCTAssertNoThrow(tracker.recordEvent(.purchase(
      orderId: "order123",
      currency: "USD",
      orderTotal: "10.00",
      cart: nil,
      products: [product]
    )))
  }

  func testRecordEvent_purchase_withCart_doesNotThrow() {
    let product = ATTNProduct(productId: "123", name: "Test", price: "10.00", quantity: 1)
    let cart = ATTNCartPayload(
      cartId: "cart123",
      cartTotal: "10.00",
      cartCoupon: "SAVE10",
      cartDiscount: "1.00"
    )

    XCTAssertNoThrow(tracker.recordEvent(.purchase(
      orderId: "order123",
      currency: "USD",
      orderTotal: "10.00",
      cart: cart,
      products: [product]
    )))
  }

  func testRecordEvent_purchase_multipleProducts_doesNotThrow() {
    let product1 = ATTNProduct(productId: "123", name: "Test 1", price: "10.00", quantity: 1)
    let product2 = ATTNProduct(productId: "456", name: "Test 2", price: "20.00", quantity: 2)

    XCTAssertNoThrow(tracker.recordEvent(.purchase(
      orderId: "order123",
      currency: "USD",
      orderTotal: "50.00",
      cart: nil,
      products: [product1, product2]
    )))
  }

  func testRecordEvent_purchase_emptyProductsArray_doesNotThrow() {
    XCTAssertNoThrow(tracker.recordEvent(.purchase(
      orderId: "order123",
      currency: "USD",
      orderTotal: "0.00",
      cart: nil,
      products: []
    )))
  }

  func testRecordEvent_purchase_withFullCart_doesNotThrow() {
    let product = ATTNProduct(
      productId: "123",
      variantId: "456",
      name: "Test Product",
      variantName: "Blue",
      imageUrl: "https://example.com/image.jpg",
      categories: ["Electronics"],
      price: "59.99",
      quantity: 2,
      productUrl: "https://example.com/product/123"
    )

    let cart = ATTNCartPayload(
      cartId: "cart456",
      cartTotal: "119.98",
      cartCoupon: "SUMMER20",
      cartDiscount: "10.00"
    )

    XCTAssertNoThrow(tracker.recordEvent(.purchase(
      orderId: "order456",
      currency: "USD",
      orderTotal: "109.98",
      cart: cart,
      products: [product]
    )))
  }

  // MARK: - CustomEvent Tests

  func testRecordEvent_customEvent_withProperties_doesNotThrow() {
    let properties = ["key1": "value1", "key2": "value2"]

    XCTAssertNoThrow(tracker.recordEvent(.customEvent(customProperties: properties)))
  }

  func testRecordEvent_customEvent_withoutProperties_doesNotThrow() {
    XCTAssertNoThrow(tracker.recordEvent(.customEvent(customProperties: nil)))
  }

  func testRecordEvent_customEvent_emptyProperties_doesNotThrow() {
    XCTAssertNoThrow(tracker.recordEvent(.customEvent(customProperties: [:])))
  }

  func testRecordEvent_customEvent_withSpecialCharacters_doesNotThrow() {
    let properties = [
      "key_with_underscore": "value",
      "key-with-dash": "value",
      "key.with.dot": "value"
    ]

    XCTAssertNoThrow(tracker.recordEvent(.customEvent(customProperties: properties)))
  }

  // MARK: - Integration Tests

  func testRecordEvent_multipleEventTypes_sequential_doesNotThrow() {
    let product = ATTNProduct(productId: "123", name: "Test", price: "10.00", quantity: 1)

    XCTAssertNoThrow(tracker.recordEvent(.productView(product: product, currency: "USD")))
    XCTAssertNoThrow(tracker.recordEvent(.addToCart(product: product, currency: "USD")))
    XCTAssertNoThrow(tracker.recordEvent(.customEvent(customProperties: ["action": "checkout_started"])))
    XCTAssertNoThrow(tracker.recordEvent(.purchase(
      orderId: "order123",
      currency: "USD",
      orderTotal: "10.00",
      cart: nil,
      products: [product]
    )))
  }

  func testRecordEvent_completeUserJourney_doesNotThrow() {
    // Simulate a complete user journey through the app
    let product1 = ATTNProduct(productId: "PROD1", name: "Widget A", price: "29.99", quantity: 1)
    let product2 = ATTNProduct(productId: "PROD2", name: "Widget B", price: "39.99", quantity: 2)

    // View product 1
    XCTAssertNoThrow(tracker.recordEvent(.productView(product: product1, currency: "USD")))

    // Add product 1 to cart
    XCTAssertNoThrow(tracker.recordEvent(.addToCart(product: product1, currency: "USD")))

    // View product 2
    XCTAssertNoThrow(tracker.recordEvent(.productView(product: product2, currency: "USD")))

    // Add product 2 to cart
    XCTAssertNoThrow(tracker.recordEvent(.addToCart(product: product2, currency: "USD")))

    // Custom event for checkout start
    XCTAssertNoThrow(tracker.recordEvent(.customEvent(customProperties: ["step": "checkout_initiated"])))

    // Complete purchase
    let cart = ATTNCartPayload(cartId: "CART123", cartTotal: "109.97", cartCoupon: "SAVE10", cartDiscount: "5.00")
    XCTAssertNoThrow(tracker.recordEvent(.purchase(
      orderId: "ORDER789",
      currency: "USD",
      orderTotal: "104.97",
      cart: cart,
      products: [product1, product2]
    )))
  }
}
