//
//  ATTNEventTracker.swift
//  attentive-ios-sdk-framework
//
//  Created by Vladimir - Work on 2024-05-30.
//

import Foundation

@objc(ATTNEventTracker)
public final class ATTNEventTracker: NSObject {
  private static var _sharedInstance: ATTNEventTracker?
  private let sdk: ATTNSDK

  @objc(initWithSdk:)
  public init(sdk: ATTNSDK) {
    self.sdk = sdk
  }

  @objc(setupWithSdk:)
  public static func setup(with sdk: ATTNSDK) {
    _sharedInstance = ATTNEventTracker(sdk: sdk)
    Loggers.event.debug("ATTNEventTracker was initialized with SDK")
  }

  @available(swift, deprecated: 0.6, message: "Please use record(event: ATTNEvent) instead.")
  @objc(recordEvent:)
  public func record(_ event: ATTNEvent) {
    sdk.send(event: event)
  }

  public func record(event: ATTNEvent) {
    sdk.send(event: event)
  }

  @objc
  public static func sharedInstance() -> ATTNEventTracker? {
    assert(_sharedInstance != nil, "ATTNEventTracker must be setup before being used")
    return _sharedInstance
  }

  // MARK: - New Event API (v2 endpoint)

  /// Records an AddToCart event to the new /mobile endpoint
  /// - Parameters:
  ///   - product: The product being added to cart
  ///   - currency: The currency code (e.g., "USD")
  public func recordAddToCart(product: ATTNProduct, currency: String) {
    sdk.sendAddToCartEvent(product: product, currency: currency)
  }

  /// Records a ProductView event to the new /mobile endpoint
  /// - Parameters:
  ///   - product: The product being viewed
  ///   - currency: The currency code (e.g., "USD")
  public func recordProductView(product: ATTNProduct, currency: String) {
    sdk.sendProductViewEvent(product: product, currency: currency)
  }

  /// Records a Purchase event to the new /mobile endpoint
  /// - Parameters:
  ///   - orderId: The order identifier
  ///   - currency: The currency code (e.g., "USD")
  ///   - orderTotal: The total order amount
  ///   - cart: Optional cart details
  ///   - products: Array of products in the purchase
  public func recordPurchase(
    orderId: String,
    currency: String,
    orderTotal: String,
    cart: ATTNCartPayload?,
    products: [ATTNProduct]
  ) {
    sdk.sendPurchaseEvent(
      orderId: orderId,
      currency: currency,
      orderTotal: orderTotal,
      cart: cart,
      products: products
    )
  }

  /// Records a MobileCustomEvent to the new /mobile endpoint
  /// - Parameters:
  ///   - customProperties: Optional dictionary of custom properties
  public func recordCustomEvent(customProperties: [String: String]?) {
    sdk.sendCustomEvent(customProperties: customProperties)
  }
}

// MARK: Internal Helpers
extension ATTNEventTracker {
  static func destroy() {
    _sharedInstance = nil
  }

  func getSdk() -> ATTNSDK {
    sdk
  }
}
