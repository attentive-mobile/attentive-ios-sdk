//
//  ATTNEventURLProvider.swift
//  attentive-ios-sdk-framework
//
//  Created by Vladimir - Work on 2024-06-06.
//

import Foundation

protocol ATTNEventURLProviding {
    func buildUrl(for userIdentity: ATTNUserIdentity, domain: String) -> URL?
    func buildUrl(for eventRequest: ATTNEventRequest, userIdentity: ATTNUserIdentity, domain: String) -> URL?
    func buildNewEventEndpointUrl(for eventRequest: ATTNEventRequest, userIdentity: ATTNUserIdentity, domain: String) -> URL?
    func buildPushTokenUrl(for userIdentity: ATTNUserIdentity, domain: String) -> URL?
}

struct ATTNEventURLProvider: ATTNEventURLProviding {
    func buildUrl(for userIdentity: ATTNUserIdentity, domain: String) -> URL? {
        var urlComponents = getUrlComponent()

        var queryParams = userIdentity.constructBaseQueryParams(domain: domain)
        queryParams["m"] = userIdentity.buildMetadataJson()
        queryParams["t"] = ATTNEventTypes.userIdentifierCollected

        Self.setFormEncodedQuery(on: &urlComponents, params: queryParams)
        return urlComponents.url
    }

    func buildUrl(for eventRequest: ATTNEventRequest, userIdentity: ATTNUserIdentity, domain: String) -> URL? {
        var urlComponents = getUrlComponent()

        var queryParams = userIdentity.constructBaseQueryParams(domain: domain)
        var combinedMetadata = userIdentity.buildBaseMetadata() as [String: Any]
        combinedMetadata.merge(eventRequest.metadata) { (current, _) in current }
        queryParams["m"] = try? ATTNJsonUtils.convertObjectToJson(combinedMetadata) ?? "{}"
        queryParams["t"] = eventRequest.eventNameAbbreviation

        if let deeplink = eventRequest.deeplink {
            queryParams["pd"] = deeplink
        }

        Self.setFormEncodedQuery(on: &urlComponents, params: queryParams)
        return urlComponents.url
    }

    func buildNewEventEndpointUrl(for eventRequest: ATTNEventRequest, userIdentity: ATTNUserIdentity, domain: String) -> URL? {
        var urlComponents = getNewEventEndpointUrlComponent()
        // TODO finish building url for new event endpoint
        var queryParams = userIdentity.constructBaseQueryParams(domain: domain)
        var combinedMetadata = userIdentity.buildBaseMetadata() as [String: Any]
        combinedMetadata.merge(eventRequest.metadata) { (current, _) in current }
        queryParams["m"] = try? ATTNJsonUtils.convertObjectToJson(combinedMetadata) ?? "{}"
        queryParams["t"] = eventRequest.eventNameAbbreviation

        if let deeplink = eventRequest.deeplink {
            queryParams["pd"] = deeplink
        }

        Self.setFormEncodedQuery(on: &urlComponents, params: queryParams)
        return urlComponents.url
    }

    func buildPushTokenUrl(for userIdentity: ATTNUserIdentity, domain: String) -> URL? {
        getUrlComponent(
            host: ATTNSDKConfiguration.Endpoint.Mobile.host,
            path: ATTNSDKConfiguration.Endpoint.Mobile.pushTokenPath,
            port: ATTNSDKConfiguration.Endpoint.Mobile.port
        ).url
    }
}

extension ATTNEventURLProvider {
    private func getUrlComponent() -> URLComponents {
        getUrlComponent(
            host: ATTNSDKConfiguration.Endpoint.Events.host,
            path: ATTNSDKConfiguration.Endpoint.Events.legacyPath,
            port: nil
        )
    }

    private func getNewEventEndpointUrlComponent() -> URLComponents {
        getUrlComponent(
            host: ATTNSDKConfiguration.Endpoint.Events.host,
            path: ATTNSDKConfiguration.Endpoint.Events.newEventPath,
            port: nil
        )
    }

    private func getUrlComponent(host: String, path: String, port: Int?) -> URLComponents {
        var components = URLComponents()
        components.scheme = ATTNSDKConfiguration.Endpoint.scheme
        components.host = host
        components.path = path
        components.port = port
        return components
    }

    private static let formEncodedAllowedCharacters: CharacterSet = {
        var chars = CharacterSet.urlQueryAllowed
        chars.remove("+")
        chars.remove("&")
        chars.remove("=")
        return chars
    }()

    static func setFormEncodedQuery(on components: inout URLComponents, params: [String: String]) {
        let queryString = params.map { key, value in
            let encodedKey = key.addingPercentEncoding(withAllowedCharacters: formEncodedAllowedCharacters) ?? key
            let encodedValue = value.addingPercentEncoding(withAllowedCharacters: formEncodedAllowedCharacters) ?? value
            return "\(encodedKey)=\(encodedValue)"
        }.joined(separator: "&")
        components.percentEncodedQuery = queryString
    }
}
