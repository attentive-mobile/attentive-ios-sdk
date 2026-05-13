//
//  ATTNError.swift
//  attentive-ios-sdk-framework
//
//  Created by Adela Gao on 8/20/25.
//

import Foundation

public enum ATTNError: Error, Equatable {
    case sdkNotInitialized
    case missingContactInfo
    @available(*, deprecated, message: "Geo-domain adjustment has been removed. This case is no longer used by the SDK.")
    case geoDomainUnavailable
    case badURL
    case invalidDomain
    case initializationFailed
    case missingPushToken
    case httpError(statusCode: Int, data: Data?)
}

extension ATTNError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .sdkNotInitialized:
            return "SDK not initialized"
        case .missingContactInfo:
            return "Provide email and/or phone"
        case .geoDomainUnavailable:
            return "Geo domain unavailable"
        case .badURL:
            return "Invalid URL"
        case .invalidDomain:
            return "The provided domain is not recognized. Please verify that the domain matches your Attentive settings."
        case .initializationFailed:
            return "SDK initialization failed"
        case .missingPushToken:
            return "Push token is not available"
        case .httpError(let statusCode, _):
            return "HTTP request failed with status code \(statusCode)"
        }
    }
}

extension ATTNError: CustomNSError {
    public static var errorDomain: String { "com.attentive.sdk" }

    public var errorCode: Int {
        switch self {
        case .sdkNotInitialized: return 1
        case .missingContactInfo: return 2
        case .geoDomainUnavailable: return 3
        case .badURL: return 4
        case .invalidDomain: return 5
        case .initializationFailed: return 6
        case .missingPushToken: return 7
        case .httpError(let statusCode, _): return 1000 + statusCode
        }
    }

    public var errorUserInfo: [String: Any] {
        var info: [String: Any] = [:]
        if case .httpError(_, let data) = self, let data = data {
            info["responseData"] = data
        }
        return info
    }
}
