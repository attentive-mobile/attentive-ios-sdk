//
//  ATTNEventTypes.swift
//  attentive-ios-sdk-framework
//
//  Created by Vladimir - Work on 2024-06-03.
//

import Foundation

enum ATTNEventTypes {
  static var purchase: String { "p" }
  static var addToCart: String { "c" }
  static var productView: String { "d" }
  static var orderConfirmed: String { "oc" }
  static var userIdentifierCollected: String { "idn" }
  static var info: String { "i" }
  static var customEvent: String { "ce" }
}

// For new /mobile endpoint

enum ATTNEventType: String, Codable {
    case purchase = "p"
    case addToCart = "c"
    case productView = "d"
}

struct ATTNIdentifiers: Codable {
    let encryptedEmail: String?
    let encryptedPhone: String?
    let otherIdentifiers: [[String: String]]?
}

struct ATTNProduct: Codable {
    let productId: String
    let variantId: String?
    let name: String
    let variantName: String?
    let imageUrl: String?
    let categories: [String]?
    let price: String
    let quantity: Int
    let productUrl: String?
}

struct ATTNCart: Codable {
    let cartId: String?
    let cartTotal: String?
    let cartCoupon: String?
    let cartDiscount: String?
}

struct ATTNAddToCartMetadata: Codable {
    let eventType: String = "AddToCart"
    let product: ATTNProduct
    let currency: String
}

struct ATTNProductViewMetadata: Codable {
    let eventType: String = "ProductView"
    let product: ATTNProduct
    let currency: String
}

struct ATTNPurchaseMetadata { //: Codable {
    let eventType: String = "Purchase"
    let orderId: String
    let currency: String
    let orderTotal: String
    let cart: ATTNCart?
    let products: [ATTNProduct]
}

struct ATTNBaseEvent<M: Codable>: Codable {
    let visitorId: String
    let version: String
    let attentiveDomain: String
    let locationHref: String?
    let referrer: String
    let eventType: ATTNEventType
    let timestamp: String
    let identifiers: ATTNIdentifiers
    let eventMetadata: M
    let sourceType: String = "mobile"
    let appSdk: String = "iOS"
}
