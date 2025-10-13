//
//  ATTNProductViewEvent+Extension.swift
//  attentive-ios-sdk-framework
//
//  Created by Vladimir - Work on 2024-06-03.
//

import Foundation

/// Codable model for the new minimal Attentive Internal Events API payload
private struct ProductViewEventPayload: Codable {
  let visitorId: String
  let version: String
  let attentiveDomain: String
  let eventType: String
  let timestamp: String
  let identifiers: [String: String]
  let eventMetadata: ProductViewMetadata
  let sourceType: String
  let appSdk: String
}

/// Metadata section inside `eventMetadata`
private struct ProductViewMetadata: Codable {
  let eventType: String
  let product: ProductMetadata
  let currency: String
}

/// Minimal product info (only productId)
private struct ProductMetadata: Codable {
  let productId: String?
}

extension ATTNProductViewEvent: ATTNEventRequestProvider {

  // MARK: - Legacy event format (existing behavior)
  var eventRequests: [ATTNEventRequest] {
    guard !items.isEmpty else {
      Loggers.event.debug("No items found in the ProductView event (legacy).")
      return []
    }

    return items.map { item in
      var metadata = [String: Any]()
      item.addItem(toDictionary: &metadata, with: priceFormatter)

      let request = ATTNEventRequest(
        metadata: metadata,
        eventNameAbbreviation: ATTNEventTypes.productView
      )
      request.deeplink = deeplink
      return request
    }
  }

  // MARK: - New internal events API format
  func eventRequests(for userIdentity: ATTNUserIdentity, domain: String) -> [ATTNEventRequest] {
    guard !items.isEmpty else {
      Loggers.event.debug("No items found in the ProductView event (new internal format).")
      return []
    }

    return items.compactMap { item in
      let product = ProductMetadata(productId: item.productId)

      let metadata = ProductViewMetadata(
        eventType: "ProductView",
        product: product,
        currency: item.price.currency ?? "USD"
      )

      let payload = ProductViewEventPayload(
        visitorId: userIdentity.visitorId,
        version: ATTNConstants.sdkVersion,
        attentiveDomain: domain,
        eventType: "ProductView",
        timestamp: ISO8601DateFormatter().string(from: Date()),
        identifiers: userIdentity.identifiers as? [String: String] ?? [:],
        eventMetadata: metadata,
        sourceType: "mobile",
        appSdk: "iOS"
      )

      guard let encodedData = try? JSONEncoder().encode(payload),
            let jsonString = String(data: encodedData, encoding: .utf8) else {
        Loggers.event.error("Failed to encode ProductView payload as JSON string.")
        return nil
      }

      guard let encodedData = try? JSONEncoder().encode(payload),
            let jsonObject = try? JSONSerialization.jsonObject(with: encodedData) else {
        Loggers.event.error("Failed to encode ProductView payload as JSON object.")
        return nil
      }

      let wrappedPayload: [String: Any] = ["d": jsonObject]
      Loggers.event.debug("📦 Wrapped minimal ProductView payload under key 'd': \(jsonString)")

      let request = ATTNEventRequest(
        metadata: wrappedPayload,
        eventNameAbbreviation: ATTNEventTypes.productView
      )

      request.deeplink = deeplink
      return request
    }
  }
}
