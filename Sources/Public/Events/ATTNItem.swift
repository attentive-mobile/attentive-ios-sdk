//
//  ATTNItem.swift
//  attentive-ios-sdk-framework
//
//  Created by Vladimir - Work on 2024-05-30.
//

import Foundation

@objc(ATTNItem)
public final class ATTNItem: NSObject {
    @objc public let productId: String
    @objc public let productVariantId: String
    @objc public let price: ATTNPrice
    @objc public var quantity: Int
    @objc public var productImage: String?
    @objc public var name: String?
    @objc public var category: String?

    @objc(initWithProductId:productVariantId:price:)
    public init(productId: String, productVariantId: String, price: ATTNPrice) {
        self.productId = productId
        self.productVariantId = productVariantId
        self.price = price
        self.quantity = 1
    }
}

// MARK: Internal Helpers
extension ATTNItem {
    func addItem(toDictionary dictionary: inout [String: Any], with priceFormatter: NumberFormatter) {
        dictionary["productId"] = productId
        dictionary["subProductId"] = productVariantId
        dictionary["price"] = priceFormatter.string(from: price.price)
        dictionary["currency"] = price.currency
        dictionary["quantity"] = "\(quantity)"

        if let category = category {
            dictionary["category"] = category
        }

        if let image = productImage {
            dictionary["image"] = image
        }

        if let name = name {
            dictionary["name"] = name
        }
    }

    /// Converts a legacy ATTNItem to the new ATTNProduct format for v2 API
    func toV2Product() -> ATTNProduct {
        // Extract category as an array if present
        let categories: [String]? = category != nil ? [category!] : nil

        return ATTNProduct(
            productId: productId,
            variantId: productVariantId,
            name: name ?? "Unknown Product",
            variantName: nil,
            imageUrl: productImage,
            categories: categories,
            price: price.price.stringValue,
            quantity: quantity,
            productUrl: nil
        )
    }
}
