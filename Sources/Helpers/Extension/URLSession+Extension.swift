//
//  URLSession+Extension.swift
//  attentive-ios-sdk-framework
//
//  Created by Vladimir - Work on 2024-06-03.
//

import Foundation

extension URLSession {
    static func build(withUserAgent userAgent: String) -> URLSession {
        let configWithUserAgent = URLSessionConfiguration.default
        let additionalHeadersWithUserAgent = ["User-Agent": userAgent]
        configWithUserAgent.httpAdditionalHeaders = additionalHeadersWithUserAgent

        return .init(configuration: configWithUserAgent)
    }
}
