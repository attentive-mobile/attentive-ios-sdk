//
//  ATTNPurchaseEvent+Extension.swift
//  attentive-ios-sdk-framework
//
//  Created by Vladimir - Work on 2024-06-03.
//

import Foundation

extension ATTNPurchaseEvent: ATTNEventRequestProvider {
    var eventRequests: [ATTNEventRequest] {
        var eventRequests = [ATTNEventRequest]()

        guard !items.isEmpty else {
            Loggers.event.debug("No items found in the purchase event.")
            return []
        }

        var cartTotal = NSDecimalNumber.zero
        for item in items {
            var metadata = [String: Any]()
            item.addItem(toDictionary: &metadata, with: priceFormatter)
            metadata["orderId"] = order.orderId

            if let cart = cart {
                metadata.addEntryIfNotNil(key: "cartId", value: cart.cartId)
                metadata.addEntryIfNotNil(key: "cartCoupon", value: cart.cartCoupon)
            }

            eventRequests.append(
                .init(
                    metadata: metadata,
                    eventNameAbbreviation: ATTNEventTypes.purchase
                )
            )

            cartTotal = cartTotal.adding(item.price.price)
        }

        let cartTotalString = priceFormatter.string(from: cartTotal)
        for eventRequest in eventRequests {
            eventRequest.metadata["cartTotal"] = cartTotalString
        }

        var orderConfirmedMetadata = [String: Any]()
        orderConfirmedMetadata["orderId"] = order.orderId
        orderConfirmedMetadata["cartTotal"] = cartTotalString
        orderConfirmedMetadata["currency"] = items.first?.price.currency

        var products = [[String: Any]]()
        for item in items {
            var product = [String: Any]()
            item.addItem(toDictionary: &product, with: priceFormatter)
            products.append(product)
        }
        orderConfirmedMetadata["products"] = try? ATTNJsonUtils.convertObjectToJson(products) ?? "[]"
        eventRequests.append(
            .init(
                metadata: orderConfirmedMetadata,
                eventNameAbbreviation: ATTNEventTypes.orderConfirmed
            )
        )

        return eventRequests
    }
}
