//
//  ATTNIdentifierType.swift
//  attentive-ios-sdk-framework
//
//  Created by Vladimir - Work on 2024-06-03.
//

import Foundation

@objc public class ATTNIdentifierType: NSObject {
    /// Your unique identifier for the user - this should be consistent across the user's lifetime, for example a database id
    @objc public static let clientUserId = "clientUserId"
    /// The user's phone number in E.164 format
    @objc public static let phone = "phone"
    /// The user's email
    @objc public static let email = "email"
    /// The user's Shopify Customer ID
    @objc public static let shopifyId = "shopifyId"
    /// The user's Klaviyo ID
    @objc public static let klaviyoId = "klaviyoId"
    /// Key-value pairs of custom identifier names and values (both Strings) to associate with this user
    @objc public static let customIdentifiers = "customIdentifiers"
}

// MARK: Internal Helpers
extension ATTNIdentifierType {
    static var allKeys: [String] = [
        clientUserId,
        phone,
        email,
        shopifyId,
        klaviyoId,
    ]
}
