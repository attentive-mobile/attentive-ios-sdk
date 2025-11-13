//
//  ATTNEventTracker.swift
//  attentive-ios-sdk-framework
//
//  Created by Vladimir - Work on 2024-05-30.
//

import Foundation

// MARK: - Event Data Models

/// Unified event data model for v2 mobile endpoint events
public enum ATTNEventData {
  case addToCart(product: ATTNProduct, currency: String)
  case productView(product: ATTNProduct, currency: String)
  case purchase(orderId: String, currency: String, orderTotal: String, cart: ATTNCartPayload?, products: [ATTNProduct])
  case customEvent(customProperties: [String: String]?)
}

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

  // MARK: - New Event API (v2 endpoint) - Centralized Entry Point

  /// Records an event to the new /mobile endpoint.
  /// This is the centralized entry point for all v2 event types.
  /// The function determines the event type and calls the appropriate SDK method.
  ///
  /// Supports the following event types:
  /// - AddToCart: Records when a product is added to cart
  /// - ProductView: Records when a product is viewed
  /// - Purchase: Records a completed purchase
  /// - CustomEvent: Records a custom mobile event
  ///
  /// - Parameter eventData: The event data containing event-specific information
  ///
  /// ```
  public func recordEvent(_ eventData: ATTNEventData) {
    switch eventData {
    case let .addToCart(product, currency):
      sdk.sendAddToCartEvent(product: product, currency: currency)

    case let .productView(product, currency):
      sdk.sendProductViewEvent(product: product, currency: currency)

    case let .purchase(orderId, currency, orderTotal, cart, products):
      sdk.sendPurchaseEvent(
        orderId: orderId,
        currency: currency,
        orderTotal: orderTotal,
        cart: cart,
        products: products
      )

    case let .customEvent(customProperties):
      sdk.sendCustomEvent(customProperties: customProperties)
    }
  }

  // MARK: - Convenience Methods (Deprecated)

  /// Records an AddToCart event to the new /mobile endpoint
  /// - Parameters:
  ///   - product: The product being added to cart
  ///   - currency: The currency code (e.g., "USD")
  /// - Note: This method is deprecated. Use `recordEvent(.addToCart(product:currency:))` instead.
  @available(*, deprecated, message: "Use recordEvent(.addToCart(product:currency:)) instead")
  public func recordAddToCart(product: ATTNProduct, currency: String) {
    recordEvent(.addToCart(product: product, currency: currency))
  }

  /// Records a ProductView event to the new /mobile endpoint
  /// - Parameters:
  ///   - product: The product being viewed
  ///   - currency: The currency code (e.g., "USD")
  /// - Note: This method is deprecated. Use `recordEvent(.productView(product:currency:))` instead.
  @available(*, deprecated, message: "Use recordEvent(.productView(product:currency:)) instead")
  public func recordProductView(product: ATTNProduct, currency: String) {
    recordEvent(.productView(product: product, currency: currency))
  }

  /// Records a Purchase event to the new /mobile endpoint
  /// - Parameters:
  ///   - orderId: The order identifier
  ///   - currency: The currency code (e.g., "USD")
  ///   - orderTotal: The total order amount
  ///   - cart: Optional cart details
  ///   - products: Array of products in the purchase
  /// - Note: This method is deprecated. Use `recordEvent(.purchase(...))` instead.
  @available(*, deprecated, message: "Use recordEvent(.purchase(orderId:currency:orderTotal:cart:products:)) instead")
  public func recordPurchase(
    orderId: String,
    currency: String,
    orderTotal: String,
    cart: ATTNCartPayload?,
    products: [ATTNProduct]
  ) {
    recordEvent(.purchase(
      orderId: orderId,
      currency: currency,
      orderTotal: orderTotal,
      cart: cart,
      products: products
    ))
  }

  /// Records a MobileCustomEvent to the new /mobile endpoint
  /// - Parameters:
  ///   - customProperties: Optional dictionary of custom properties
  /// - Note: This method is deprecated. Use `recordEvent(.customEvent(customProperties:))` instead.
  @available(*, deprecated, message: "Use recordEvent(.customEvent(customProperties:)) instead")
  public func recordCustomEvent(customProperties: [String: String]?) {
    recordEvent(.customEvent(customProperties: customProperties))
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
