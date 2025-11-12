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

  // MARK: - recordAddToCart Tests

  func testRecordAddToCart_validProduct_doesNotThrow() {
    let product = ATTNProduct(
      productId: "123",
      variantId: "456",
      name: "Test Product",
      variantName: nil,
      imageUrl: nil,
      categories: ["Electronics"],
      price: "59.99",
      quantity: 1,
      productUrl: nil
    )

    XCTAssertNoThrow(tracker.recordAddToCart(product: product, currency: "USD"))
  }

  func testRecordAddToCart_productWithAllFields_doesNotThrow() {
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

    XCTAssertNoThrow(tracker.recordAddToCart(product: product, currency: "USD"))
  }

  func testRecordAddToCart_differentCurrencies_doesNotThrow() {
    let product = ATTNProduct(productId: "123", name: "Test", price: "10.00", quantity: 1)

    XCTAssertNoThrow(tracker.recordAddToCart(product: product, currency: "USD"))
    XCTAssertNoThrow(tracker.recordAddToCart(product: product, currency: "EUR"))
    XCTAssertNoThrow(tracker.recordAddToCart(product: product, currency: "GBP"))
  }

  // MARK: - recordProductView Tests

  func testRecordProductView_validProduct_doesNotThrow() {
    let product = ATTNProduct(
      productId: "123",
      name: "Test Product",
      price: "59.99",
      quantity: 1
    )

    XCTAssertNoThrow(tracker.recordProductView(product: product, currency: "USD"))
  }

  func testRecordProductView_productWithOptionalFields_doesNotThrow() {
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

    XCTAssertNoThrow(tracker.recordProductView(product: product, currency: "USD"))
  }

  // MARK: - recordPurchase Tests

  func testRecordPurchase_withoutCart_doesNotThrow() {
    let product = ATTNProduct(productId: "123", name: "Test", price: "10.00", quantity: 1)

    XCTAssertNoThrow(tracker.recordPurchase(
      orderId: "order123",
      currency: "USD",
      orderTotal: "10.00",
      cart: nil,
      products: [product]
    ))
  }

  func testRecordPurchase_withCart_doesNotThrow() {
    let product = ATTNProduct(productId: "123", name: "Test", price: "10.00", quantity: 1)
    let cart = ATTNCartPayload(
      cartId: "cart123",
      cartTotal: "10.00",
      cartCoupon: "SAVE10",
      cartDiscount: "1.00"
    )

    XCTAssertNoThrow(tracker.recordPurchase(
      orderId: "order123",
      currency: "USD",
      orderTotal: "10.00",
      cart: cart,
      products: [product]
    ))
  }

  func testRecordPurchase_multipleProducts_doesNotThrow() {
    let product1 = ATTNProduct(productId: "123", name: "Test 1", price: "10.00", quantity: 1)
    let product2 = ATTNProduct(productId: "456", name: "Test 2", price: "20.00", quantity: 2)

    XCTAssertNoThrow(tracker.recordPurchase(
      orderId: "order123",
      currency: "USD",
      orderTotal: "50.00",
      cart: nil,
      products: [product1, product2]
    ))
  }

  func testRecordPurchase_emptyProductsArray_doesNotThrow() {
    XCTAssertNoThrow(tracker.recordPurchase(
      orderId: "order123",
      currency: "USD",
      orderTotal: "0.00",
      cart: nil,
      products: []
    ))
  }

  // MARK: - recordCustomEvent Tests

  func testRecordCustomEvent_withProperties_doesNotThrow() {
    let properties = ["key1": "value1", "key2": "value2"]

    XCTAssertNoThrow(tracker.recordCustomEvent(customProperties: properties))
  }

  func testRecordCustomEvent_withoutProperties_doesNotThrow() {
    XCTAssertNoThrow(tracker.recordCustomEvent(customProperties: nil))
  }

  func testRecordCustomEvent_emptyProperties_doesNotThrow() {
    XCTAssertNoThrow(tracker.recordCustomEvent(customProperties: [:]))
  }

  func testRecordCustomEvent_withSpecialCharacters_doesNotThrow() {
    let properties = [
      "key_with_underscore": "value",
      "key-with-dash": "value",
      "key.with.dot": "value"
    ]

    XCTAssertNoThrow(tracker.recordCustomEvent(customProperties: properties))
  }

  // MARK: - Integration Tests

  func testMultipleEventTypes_sequential_doesNotThrow() {
    let product = ATTNProduct(productId: "123", name: "Test", price: "10.00", quantity: 1)

    XCTAssertNoThrow(tracker.recordProductView(product: product, currency: "USD"))
    XCTAssertNoThrow(tracker.recordAddToCart(product: product, currency: "USD"))
    XCTAssertNoThrow(tracker.recordCustomEvent(customProperties: ["action": "checkout_started"]))
    XCTAssertNoThrow(tracker.recordPurchase(
      orderId: "order123",
      currency: "USD",
      orderTotal: "10.00",
      cart: nil,
      products: [product]
    ))
  }

  func testSharedInstance_afterSetup_returnsValidInstance() {
    XCTAssertNotNil(ATTNEventTracker.sharedInstance())
  }
}
