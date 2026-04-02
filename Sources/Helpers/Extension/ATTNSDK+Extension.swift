//
//  ATTNSDK+Extension.swift
//  attentive-ios-sdk-framework
//
//  Created by Vladimir - Work on 2024-06-17.
//

import Foundation

extension ATTNSDK {
    func send(event: ATTNEvent) {
        // Automatically convert legacy events to v2 format
        if let addToCartEvent = event as? ATTNAddToCartEvent {
            sendLegacyAddToCartAsV2(addToCartEvent)
        } else if let productViewEvent = event as? ATTNProductViewEvent {
            sendLegacyProductViewAsV2(productViewEvent)
        } else if let purchaseEvent = event as? ATTNPurchaseEvent {
            sendLegacyPurchaseAsV2(purchaseEvent)
        } else if let customEvent = event as? ATTNCustomEvent {
            sendLegacyCustomEventAsV2(customEvent)
        } else {
            // Fallback to legacy API for unknown event types
            api.send(event: event, userIdentity: userIdentity)
        }
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

    func sendCustomEvent(customProperties: [String: String]?) {
        let metadata = ATTNMobileCustomEventMetadata(customProperties: customProperties)
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

    // MARK: - Legacy to V2 Conversion Methods

    private func sendLegacyAddToCartAsV2(_ event: ATTNAddToCartEvent) {
        guard let firstItem = event.items.first else {
            Loggers.event.error("AddToCartEvent has no items, cannot convert to v2")
            return
        }

        let product = firstItem.toV2Product()
        sendAddToCartEvent(product: product, currency: firstItem.price.currency)

        if event.items.count > 1 {
            Loggers.event.info("AddToCartEvent had \(event.items.count) items, v2 API only supports single product per event. Only first item was sent.")
        }
    }

    private func sendLegacyProductViewAsV2(_ event: ATTNProductViewEvent) {
        guard let firstItem = event.items.first else {
            Loggers.event.error("ProductViewEvent has no items, cannot convert to v2")
            return
        }

        let product = firstItem.toV2Product()
        sendProductViewEvent(product: product, currency: firstItem.price.currency)

        if event.items.count > 1 {
            Loggers.event.info("ProductViewEvent had \(event.items.count) items, v2 API only supports single product per event. Only first item was sent.")
        }
    }

    private func sendLegacyPurchaseAsV2(_ event: ATTNPurchaseEvent) {
        guard !event.items.isEmpty else {
            Loggers.event.error("PurchaseEvent has no items, cannot convert to v2")
            return
        }

        // Convert all items to v2 products
        let products = event.items.map { $0.toV2Product() }

        // Calculate order total from items
        let orderTotal = event.items.reduce(NSDecimalNumber.zero) { total, item in
            total.adding(item.price.price.multiplying(by: NSDecimalNumber(value: item.quantity)))
        }

        // Get currency from first item (all items should have same currency)
        let currency = event.items.first?.price.currency ?? "USD"

        // Convert cart if present
        let cartPayload: ATTNCartPayload?
        if let legacyCart = event.cart {
            cartPayload = ATTNCartPayload(
                from: legacyCart,
                total: orderTotal.stringValue,
                discount: nil
            )
        } else {
            cartPayload = nil
        }

        sendPurchaseEvent(
            orderId: event.order.orderId,
            currency: currency,
            orderTotal: orderTotal.stringValue,
            cart: cartPayload,
            products: products
        )
    }

    private func sendLegacyCustomEventAsV2(_ event: ATTNCustomEvent) {
        // For custom events, we pass the properties directly
        // The type field from legacy custom event is not used in v2 as all custom events
        // use the "MobileCustomEvent" type
        sendCustomEvent(customProperties: event.properties)
    }
}
