//
//  ATTNEventTypes.swift
//  attentive-ios-sdk-framework
//
//  Created by Vladimir - Work on 2024-06-03.
//

import Foundation

// MARK: - Legacy Event Constants (Internal use only)
enum ATTNEventTypes {
  static var purchase: String { "p" }
  static var addToCart: String { "c" }
  static var productView: String { "d" }
  static var orderConfirmed: String { "oc" }
  static var userIdentifierCollected: String { "idn" }
  static var info: String { "i" }
  static var customEvent: String { "ce" }
}

// MARK: - New /mobile Event Models (Public)

/// Represents event type identifiers for the Internal Events API.
public enum ATTNEventType: String, Codable {
  case purchase = "p"
  case addToCart = "c"
  case productView = "d"
}

/// Identifiers used to represent user identity in the event payload.
public struct ATTNIdentifiers: Codable {
  public let encryptedEmail: String?
  public let encryptedPhone: String?
  public let otherIdentifiers: [[String: String]]?

  public init(
    encryptedEmail: String? = nil,
    encryptedPhone: String? = nil,
    otherIdentifiers: [[String: String]]? = nil
  ) {
    self.encryptedEmail = encryptedEmail
    self.encryptedPhone = encryptedPhone
    self.otherIdentifiers = otherIdentifiers
  }
}

/// Represents an individual product in an event payload.
public struct ATTNProduct: Codable {
  public let productId: String
  public let variantId: String?
  public let name: String
  public let variantName: String?
  public let imageUrl: String?
  public let categories: [String]?
  public let price: String
  public let quantity: Int
  public let productUrl: String?

  public init(
    productId: String,
    variantId: String? = nil,
    name: String,
    variantName: String? = nil,
    imageUrl: String? = nil,
    categories: [String]? = nil,
    price: String,
    quantity: Int,
    productUrl: String? = nil
  ) {
    self.productId = productId
    self.variantId = variantId
    self.name = name
    self.variantName = variantName
    self.imageUrl = imageUrl
    self.categories = categories
    self.price = price
    self.quantity = quantity
    self.productUrl = productUrl
  }
}

/// Represents cart details included in purchase or checkout events.
public struct ATTNCartPayload: Codable {
  public let cartId: String?
  public let cartTotal: String?
  public let cartCoupon: String?
  public let cartDiscount: String?

  public init(
    cartId: String? = nil,
    cartTotal: String? = nil,
    cartCoupon: String? = nil,
    cartDiscount: String? = nil
  ) {
    self.cartId = cartId
    self.cartTotal = cartTotal
    self.cartCoupon = cartCoupon
    self.cartDiscount = cartDiscount
  }

  /// Convenience init from legacy ATTNCart (Objective-C model)
  public init(from legacyCart: ATTNCart?, total: String? = nil, discount: String? = nil) {
    self.cartId = legacyCart?.cartId
    self.cartCoupon = legacyCart?.cartCoupon
    self.cartTotal = total
    self.cartDiscount = discount
  }
}

/// Metadata for "AddToCart" events.
public struct ATTNAddToCartMetadata: Codable {
  public let eventType: String = "AddToCart"
  public let product: ATTNProduct
  public let currency: String

  public init(product: ATTNProduct, currency: String) {
    self.product = product
    self.currency = currency
  }
}


public struct ATTNProductViewMetadata: Codable {
  public let eventType: String = "ProductView"
  public let product: ATTNProduct
  public let currency: String

  public init(product: ATTNProduct, currency: String) {
    self.product = product
    self.currency = currency
  }
}

/// Metadata for "Purchase" events.
public struct ATTNPurchaseMetadata: Codable {
  public let eventType: String = "Purchase"
  public let orderId: String
  public let currency: String
  public let orderTotal: String
  public let cart: ATTNCartPayload?
  public let products: [ATTNProduct]

  public init(
    orderId: String,
    currency: String,
    orderTotal: String,
    cart: ATTNCartPayload? = nil,
    products: [ATTNProduct]
  ) {
    self.orderId = orderId
    self.currency = currency
    self.orderTotal = orderTotal
    self.cart = cart
    self.products = products
  }
}

/// Represents a generic base event sent to the Attentive Internal Events API.
public struct ATTNBaseEvent<M: Codable>: Codable {
  public let visitorId: String
  public let version: String
  public let attentiveDomain: String
  public let locationHref: String?
  public let referrer: String
  public let eventType: ATTNEventType
  public let timestamp: String
  public let identifiers: ATTNIdentifiers
  public let eventMetadata: M
  public let sourceType: String
  public let appSdk: String

  public init(
    visitorId: String,
    version: String,
    attentiveDomain: String,
    locationHref: String? = nil,
    referrer: String,
    eventType: ATTNEventType,
    timestamp: String,
    identifiers: ATTNIdentifiers,
    eventMetadata: M,
    sourceType: String = "mobile",
    appSdk: String = "iOS"
  ) {
    self.visitorId = visitorId
    self.version = version
    self.attentiveDomain = attentiveDomain
    self.locationHref = locationHref
    self.referrer = referrer
    self.eventType = eventType
    self.timestamp = timestamp
    self.identifiers = identifiers
    self.eventMetadata = eventMetadata
    self.sourceType = sourceType
    self.appSdk = appSdk
  }
}
