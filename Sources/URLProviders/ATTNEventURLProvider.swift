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
    private enum Constants {
        static var scheme: String { "https" }
        static var host: String { "events.attentivemobile.com" }
        static var path: String { "/e" }
        static var newEventPath: String { "/mobile" }

        static var pushHost: String { "mobile.attentivemobile.com" }
        static var pushPath: String { "/token" }
        static var pushPort: Int { 443 }
    }

    func buildUrl(for userIdentity: ATTNUserIdentity, domain: String) -> URL? {
        var urlComponents = getUrlComponent()

        var queryParams = userIdentity.constructBaseQueryParams(domain: domain)
        queryParams["m"] = userIdentity.buildMetadataJson()
        queryParams["t"] = ATTNEventTypes.userIdentifierCollected

        urlComponents.queryItems = queryParams.map { .init(name: $0.key, value: $0.value) }
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

        urlComponents.queryItems = queryParams.map { .init(name: $0.key, value: $0.value) }
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

        urlComponents.queryItems = queryParams.map { .init(name: $0.key, value: $0.value) }
        return urlComponents.url
    }

    func buildPushTokenUrl(for userIdentity: ATTNUserIdentity, domain: String) -> URL? {
        var components = getUrlComponent(
            host: Constants.pushHost,
            path: Constants.pushPath,
            port: Constants.pushPort
        )
        return components.url
    }
}

extension ATTNEventURLProvider {
    private func getUrlComponent() -> URLComponents {
        var urlComponent = URLComponents()
        urlComponent.scheme = Constants.scheme
        urlComponent.host = Constants.host
        urlComponent.path = Constants.path
        return urlComponent
    }

    private func getNewEventEndpointUrlComponent() -> URLComponents {
        var urlComponent = URLComponents()
        urlComponent.scheme = Constants.scheme
        urlComponent.host = Constants.host
        urlComponent.path = Constants.newEventPath
        return urlComponent
    }

    private func getUrlComponent(host: String, path: String, port: Int?) -> URLComponents {
        var c = URLComponents()
        c.scheme = Constants.scheme
        c.host   = host
        c.path   = path
        c.port   = port
        return c
    }
}
