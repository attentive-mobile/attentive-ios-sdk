//
//  ATTNSDK+Extension.swift
//  attentive-ios-sdk-framework
//
//  Created by Vladimir - Work on 2024-06-17.
//

import Foundation

extension ATTNSDK {
    func send(event: ATTNEvent) {
        if useV2Endpoint {
            sendLegacyEventAsV2(event)
            return
        }
        api.send(event: event, userIdentity: userIdentity)
    }

    private func sendLegacyEventAsV2(_ event: ATTNEvent) {
        if let purchase = event as? ATTNPurchaseEvent {
            guard !purchase.items.isEmpty else {
                Loggers.event.debug("No items found in the purchase event, skipping v2 send.")
                return
            }
            let products = purchase.items.map { product(from: $0) }
            let cart = ATTNCartPayload(from: purchase.cart)
            let currency = purchase.items[0].price.currency
            let orderTotal = purchase.items.reduce(NSDecimalNumber.zero) { total, item in
                let quantity = NSDecimalNumber(value: item.quantity)
                return total.adding(item.price.price.multiplying(by: quantity))
            }
            sendPurchaseEvent(
                orderId: purchase.order.orderId,
                currency: currency,
                orderTotal: orderTotal.stringValue,
                cart: cart,
                products: products
            )
            return
        }

        if let addToCart = event as? ATTNAddToCartEvent {
            guard !addToCart.items.isEmpty else {
                Loggers.event.debug("No items found in the AddToCart event, skipping v2 send.")
                return
            }
            for item in addToCart.items {
                sendAddToCartEvent(product: product(from: item), currency: item.price.currency)
            }
            return
        }

        if let productView = event as? ATTNProductViewEvent {
            guard !productView.items.isEmpty else {
                Loggers.event.debug("No items found in the ProductView event, skipping v2 send.")
                return
            }
            for item in productView.items {
                sendProductViewEvent(product: product(from: item), currency: item.price.currency)
            }
            return
        }

        if let customEvent = event as? ATTNCustomEvent {
            sendCustomEvent(type: customEvent.type, customProperties: customEvent.properties)
            return
        }

        Loggers.event.debug("Unsupported event type for v2 conversion, falling back to legacy.")
        api.send(event: event, userIdentity: userIdentity)
    }

    private func product(from item: ATTNItem) -> ATTNProduct {
        ATTNProduct(
            productId: item.productId,
            variantId: item.productVariantId,
            name: item.name ?? "",
            imageUrl: item.productImage,
            categories: item.category.map { [$0] },
            price: item.price.price.stringValue,
            quantity: item.quantity
        )
    }

    func initializeSkipFatigueOnCreatives() {
        if let skipFatigueValue = ProcessInfo.processInfo.environment[ATTNConstants.skipFatigueEnvKey] {
            self.skipFatigueOnCreative = skipFatigueValue.booleanValue
            Loggers.creative.info("SKIP_FATIGUE_ON_CREATIVE: \(skipFatigueValue, privacy: .public)")
        } else {
            self.skipFatigueOnCreative = false
        }
    }

    // MARK: - New Event API (v2 endpoint)

    func sendAddToCartEvent(product: ATTNProduct, currency: String) {
        let metadata = ATTNAddToCartMetadata(product: product, currency: currency)
        sendNewEventInternal(eventType: .addToCart, metadata: metadata)
    }

    func sendProductViewEvent(product: ATTNProduct, currency: String) {
        let metadata = ATTNProductViewMetadata(product: product, currency: currency)
        sendNewEventInternal(eventType: .productView, metadata: metadata)
    }

    func sendPurchaseEvent(
        orderId: String,
        currency: String,
        orderTotal: String,
        cart: ATTNCartPayload?,
        products: [ATTNProduct]
    ) {
        let metadata = ATTNPurchaseMetadata(
            orderId: orderId,
            currency: currency,
            orderTotal: orderTotal,
            cart: cart,
            products: products
        )
        sendNewEventInternal(eventType: .purchase, metadata: metadata)
    }

    func sendCustomEvent(type: String? = nil, customProperties: [String: String]?) {
        let metadata = ATTNMobileCustomEventMetadata(type: type, customProperties: customProperties)
        sendNewEventInternal(eventType: .mobileCustomEvent, metadata: metadata)
    }

    private func sendNewEventInternal<M: Codable>(eventType: ATTNEventType, metadata: M) {
        // Get current timestamp in ISO8601 format
        let timestamp = ISO8601DateFormatter().string(from: Date())

        // Create identifiers from userIdentity
        let identifiers = ATTNIdentifiers(
            encryptedEmail: userIdentity.encryptedEmail,
            encryptedPhone: userIdentity.encryptedPhone,
            otherIdentifiers: nil
        )

        // Create the base event
        let event = ATTNBaseEvent(
            visitorId: userIdentity.visitorId,
            version: ATTNConstants.sdkVersion,
            attentiveDomain: domain,
            locationHref: nil,
            referrer: "",
            eventType: eventType,
            timestamp: timestamp,
            identifiers: identifiers,
            eventMetadata: metadata,
            genericMetadata: nil,
            sourceType: "mobile",
            appSdk: "iOS"
        )

        // Create the legacy event request for URL building
        let eventNameAbbreviation: String
        switch eventType {
        case .addToCart:
            eventNameAbbreviation = ATTNEventTypes.addToCart
        case .productView:
            eventNameAbbreviation = ATTNEventTypes.productView
        case .purchase:
            eventNameAbbreviation = ATTNEventTypes.purchase
        case .mobileCustomEvent:
            eventNameAbbreviation = ATTNEventTypes.customEvent
        }

        let eventRequest = ATTNEventRequest(
            metadata: [:],
            eventNameAbbreviation: eventNameAbbreviation
        )
        Loggers.event.debug("Sending v2 \(eventType.rawValue, privacy: .public) event: \(eventRequest, privacy: .public)")

        // Send via API
        api.sendNewEvent(event: event, eventRequest: eventRequest, userIdentity: userIdentity, callback: nil)
    }
}
