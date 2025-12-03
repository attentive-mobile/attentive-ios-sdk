//
//  ATTNSDK+Extension.swift
//  attentive-ios-sdk-framework
//
//  Created by Vladimir - Work on 2024-06-17.
//

import Foundation

extension ATTNSDK {
    func send(event: ATTNEvent) {
        api.send(event: event, userIdentity: userIdentity)
    }

    func initializeSkipFatigueOnCreatives() {
        if let skipFatigueValue = ProcessInfo.processInfo.environment[ATTNConstants.skipFatigueEnvKey] {
            self.skipFatigueOnCreative = skipFatigueValue.booleanValue
            Loggers.creative.info("SKIP_FATIGUE_ON_CREATIVE: \(skipFatigueValue)")
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
        Loggers.event.debug("Sending v2 \(eventType.rawValue) event: \(eventRequest)")

        // Send via API
        api.sendNewEvent(event: event, eventRequest: eventRequest, userIdentity: userIdentity, callback: nil)
    }
}
