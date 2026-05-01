//
//  ATTNSDK+Extension.swift
//  attentive-ios-sdk-framework
//
//  Created by Vladimir - Work on 2024-06-17.
//

import Foundation

extension ATTNSDK {
    func send(event: ATTNEvent) {
        if useV2Endpoint, let v2Event = convertLegacyEventToV2(event) {
            recordV2EventData(v2Event)
            return
        }
        api.send(event: event, userIdentity: userIdentity)
    }

    private func convertLegacyEventToV2(_ event: ATTNEvent) -> ATTNEventData? {
        if let purchase = event as? ATTNPurchaseEvent {
            let products = purchase.items.map { item in
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
            let cart = ATTNCartPayload(from: purchase.cart)
            let currency = purchase.items.first?.price.currency ?? "USD"
            let orderTotal = products.reduce(0.0) {
                $0 + (Double($1.price) ?? 0) * Double($1.quantity)
            }
            return .purchase(
                orderId: purchase.order.orderId,
                currency: currency,
                orderTotal: String(format: "%.2f", orderTotal),
                cart: cart,
                products: products
            )
        }

        if let addToCart = event as? ATTNAddToCartEvent, let item = addToCart.items.first {
            let product = ATTNProduct(
                productId: item.productId,
                variantId: item.productVariantId,
                name: item.name ?? "",
                imageUrl: item.productImage,
                categories: item.category.map { [$0] },
                price: item.price.price.stringValue,
                quantity: item.quantity
            )
            return .addToCart(product: product, currency: item.price.currency)
        }

        if let productView = event as? ATTNProductViewEvent, let item = productView.items.first {
            let product = ATTNProduct(
                productId: item.productId,
                variantId: item.productVariantId,
                name: item.name ?? "",
                imageUrl: item.productImage,
                categories: item.category.map { [$0] },
                price: item.price.price.stringValue,
                quantity: item.quantity
            )
            return .productView(product: product, currency: item.price.currency)
        }

        if let customEvent = event as? ATTNCustomEvent {
            return .customEvent(customProperties: customEvent.properties)
        }

        return nil
    }

    private func recordV2EventData(_ eventData: ATTNEventData) {
        switch eventData {
        case let .addToCart(product, currency):
            sendAddToCartEvent(product: product, currency: currency)
        case let .productView(product, currency):
            sendProductViewEvent(product: product, currency: currency)
        case let .purchase(orderId, currency, orderTotal, cart, products):
            sendPurchaseEvent(orderId: orderId, currency: currency, orderTotal: orderTotal, cart: cart, products: products)
        case let .customEvent(customProperties):
            sendCustomEvent(customProperties: customProperties)
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
}
