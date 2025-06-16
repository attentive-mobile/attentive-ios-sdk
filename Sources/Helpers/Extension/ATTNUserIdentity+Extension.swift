//
//  ATTNUserIdentity+Extension.swift
//  attentive-ios-sdk-framework
//
//  Created by Vladimir - Work on 2024-06-03.
//

import Foundation

// MARK: Internal Helpers
extension ATTNUserIdentity {
  func buildExternalVendorIdsJson() -> String {
    var ids: [[String: String]] = []

    if let clientId = identifiers[ATTNIdentifierType.clientUserId] as? String {
      ids.append(["vendor": ATTNExternalVendorTypes.clientUser, "id": clientId])
    }
    if let klaviyoId = identifiers[ATTNIdentifierType.klaviyoId] as? String {
      ids.append(["vendor": ATTNExternalVendorTypes.klaviyo, "id": klaviyoId])
    }
    if let shopifyId = identifiers[ATTNIdentifierType.shopifyId] as? String {
      ids.append(["vendor": ATTNExternalVendorTypes.shopify, "id": shopifyId])
    }
    if let customIdentifiers = identifiers[ATTNIdentifierType.customIdentifiers] as? [String: String] {
      for (key, value) in customIdentifiers {
        ids.append(["vendor": ATTNExternalVendorTypes.customUser, "id": value, "name": key])
      }
    }

    do {
      return try ATTNJsonUtils.convertObjectToJson(ids) ?? "[]"
    } catch {
      Loggers.event.error("Could not serialize the external vendor ids. Returning an empty array. Error: '\(error.localizedDescription)'")
      return "[]"
    }
  }

  func buildBaseMetadata() -> [String: String] {
    var metadata: [String: String] = [:]
    metadata["source"] = "msdk"

    if let phone = identifiers[ATTNIdentifierType.phone] as? String {
      metadata[ATTNIdentifierType.phone] = phone
    }

    if let email = identifiers[ATTNIdentifierType.email] as? String {
      metadata[ATTNIdentifierType.email] = email
    }

    return metadata
  }

  func buildMetadataJson() -> String {
    let metadata = buildBaseMetadata()

    do {
      return try ATTNJsonUtils.convertObjectToJson(metadata) ?? "{}"
    } catch {
      Loggers.event.error("Could not serialize the external vendor ids. Returning an empty blob. Error: '\(error.localizedDescription)'")
      return "{}"
    }
  }

  func constructBaseQueryParams(domain: String) -> [String: String] {
    var queryParams: [String: String] = [:]
    queryParams["tag"] = "modern"
    queryParams["v"] = "mobile-app"
    queryParams["c"] = domain
    queryParams["lt"] = "0"
    queryParams["evs"] = buildExternalVendorIdsJson()
    queryParams["u"] = visitorId
    return queryParams
  }
}

extension URLQueryItem {
    func percentEncoded() -> URLQueryItem {
        guard let value = self.value else { return self }

        let encodedValue = value
            .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)?
            .replacingOccurrences(of: "+", with: "%2B")

        return URLQueryItem(name: self.name, value: encodedValue)
    }
}

extension Array where Element == URLQueryItem {
    func percentEncoded() -> [URLQueryItem] {
        self.map { $0.percentEncoded() }
    }
}
