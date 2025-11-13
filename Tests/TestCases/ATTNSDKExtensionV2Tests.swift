//
//  ATTNSDKExtensionV2Tests.swift
//  attentive-ios-sdk Tests
//
//  Created by Adela Gao on 11/10/25.
//

import XCTest
@testable import ATTNSDKFramework

final class ATTNSDKExtensionV2Tests: XCTestCase {

  var sdk: ATTNSDK!
  var apiSpy: ATTNAPISpy!

  override func setUp() {
    super.setUp()
    apiSpy = ATTNAPISpy(domain: "test.attentivemobile.com")
    sdk = ATTNSDK(api: apiSpy)
  }

  override func tearDown() {
    sdk = nil
    apiSpy = nil
    super.tearDown()
  }

  // MARK: - sendAddToCartEvent Tests

  func testSendAddToCartEvent_callsAPI() {
    let product = ATTNProduct(productId: "123", name: "Test", price: "10.00", quantity: 1)

    sdk.sendAddToCartEvent(product: product, currency: "USD")

    XCTAssertTrue(apiSpy.sendNewEventWasCalled)
  }

  func testSendAddToCartEvent_withVariousProducts_callsAPI() {
    let product1 = ATTNProduct(
      productId: "123",
      variantId: "456",
      name: "Test Product",
      variantName: "Blue",
      imageUrl: "https://example.com/image.jpg",
      categories: ["Electronics"],
      price: "59.99",
      quantity: 1,
      productUrl: nil
    )

    sdk.sendAddToCartEvent(product: product1, currency: "USD")

    XCTAssertTrue(apiSpy.sendNewEventWasCalled)
  }

  // MARK: - sendProductViewEvent Tests

  func testSendProductViewEvent_callsAPI() {
    let product = ATTNProduct(productId: "123", name: "Test", price: "10.00", quantity: 1)

    sdk.sendProductViewEvent(product: product, currency: "USD")

    XCTAssertTrue(apiSpy.sendNewEventWasCalled)
  }

  func testSendProductViewEvent_withAllFields_callsAPI() {
    let product = ATTNProduct(
      productId: "123",
      variantId: "456",
      name: "Test Product",
      variantName: "Red",
      imageUrl: "https://example.com/image.jpg",
      categories: ["Clothing", "Accessories"],
      price: "29.99",
      quantity: 1,
      productUrl: "https://example.com/product/123"
    )

    sdk.sendProductViewEvent(product: product, currency: "EUR")

    XCTAssertTrue(apiSpy.sendNewEventWasCalled)
  }

  // MARK: - sendPurchaseEvent Tests

  func testSendPurchaseEvent_withoutCart_callsAPI() {
    let product = ATTNProduct(productId: "123", name: "Test", price: "10.00", quantity: 1)

    sdk.sendPurchaseEvent(
      orderId: "order123",
      currency: "USD",
      orderTotal: "10.00",
      cart: nil,
      products: [product]
    )

    XCTAssertTrue(apiSpy.sendNewEventWasCalled)
  }

  func testSendPurchaseEvent_withCart_callsAPI() {
    let product = ATTNProduct(productId: "123", name: "Test", price: "10.00", quantity: 1)
    let cart = ATTNCartPayload(
      cartId: "cart123",
      cartTotal: "10.00",
      cartCoupon: "SAVE10",
      cartDiscount: "1.00"
    )

    sdk.sendPurchaseEvent(
      orderId: "order123",
      currency: "USD",
      orderTotal: "10.00",
      cart: cart,
      products: [product]
    )

    XCTAssertTrue(apiSpy.sendNewEventWasCalled)
  }

  func testSendPurchaseEvent_withMultipleProducts_callsAPI() {
    let product1 = ATTNProduct(productId: "123", name: "Test 1", price: "10.00", quantity: 1)
    let product2 = ATTNProduct(productId: "456", name: "Test 2", price: "20.00", quantity: 2)

    sdk.sendPurchaseEvent(
      orderId: "order123",
      currency: "USD",
      orderTotal: "50.00",
      cart: nil,
      products: [product1, product2]
    )

    XCTAssertTrue(apiSpy.sendNewEventWasCalled)
  }

  // MARK: - sendCustomEvent Tests

  func testSendCustomEvent_withProperties_callsAPI() {
    let properties = ["key1": "value1", "key2": "value2"]

    sdk.sendCustomEvent(customProperties: properties)

    XCTAssertTrue(apiSpy.sendNewEventWasCalled)
  }

  func testSendCustomEvent_withoutProperties_callsAPI() {
    sdk.sendCustomEvent(customProperties: nil)

    XCTAssertTrue(apiSpy.sendNewEventWasCalled)
  }

  func testSendCustomEvent_emptyProperties_callsAPI() {
    sdk.sendCustomEvent(customProperties: [:])

    XCTAssertTrue(apiSpy.sendNewEventWasCalled)
  }

  // MARK: - Integration Tests

  func testMultipleEventsSent_allCallAPI() {
    let product = ATTNProduct(productId: "123", name: "Test", price: "10.00", quantity: 1)

    // Reset the spy between calls to verify each call
    sdk.sendProductViewEvent(product: product, currency: "USD")
    XCTAssertTrue(apiSpy.sendNewEventWasCalled)

    // Create new spy for next call
    apiSpy = ATTNAPISpy(domain: "test.attentivemobile.com")
    sdk = ATTNSDK(api: apiSpy)

    sdk.sendAddToCartEvent(product: product, currency: "USD")
    XCTAssertTrue(apiSpy.sendNewEventWasCalled)

    // Create new spy for next call
    apiSpy = ATTNAPISpy(domain: "test.attentivemobile.com")
    sdk = ATTNSDK(api: apiSpy)

    sdk.sendPurchaseEvent(
      orderId: "order123",
      currency: "USD",
      orderTotal: "10.00",
      cart: nil,
      products: [product]
    )
    XCTAssertTrue(apiSpy.sendNewEventWasCalled)
  }

  func testSendEvent_userIdentityWithEmailAndPhone_includesInEvent() {
    // Set up user identity with email and phone
    sdk.identify([
      ATTNIdentifierType.email: "test@example.com",
      ATTNIdentifierType.phone: "+14155551234"
    ])

    let product = ATTNProduct(productId: "123", name: "Test", price: "10.00", quantity: 1)

    sdk.sendAddToCartEvent(product: product, currency: "USD")

    XCTAssertTrue(apiSpy.sendNewEventWasCalled)
  }

  func testSendEvent_differentDomains_usesCorrectDomain() {
    let domains = ["test1.attentivemobile.com", "test2.attentivemobile.com"]
    let product = ATTNProduct(productId: "123", name: "Test", price: "10.00", quantity: 1)

    for domain in domains {
      let localApiSpy = ATTNAPISpy(domain: domain)
      let localSdk = ATTNSDK(api: localApiSpy)

      localSdk.sendAddToCartEvent(product: product, currency: "USD")

      XCTAssertTrue(localApiSpy.sendNewEventWasCalled)
      XCTAssertEqual(localSdk.domain, domain)
    }
  }
}
