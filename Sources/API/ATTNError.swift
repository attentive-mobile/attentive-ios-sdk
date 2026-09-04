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
    case inboxRequestFailed(statusCode: Int)
    case inboxResponseDecodeFailed
    case initializationFailed
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
        case .inboxRequestFailed(let statusCode):
            return "Inbox request failed with status code \(statusCode)"
        case .inboxResponseDecodeFailed:
            return "Failed to decode inbox response"
        case .initializationFailed:
            return "SDK initialization failed"
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
        case .inboxRequestFailed: return 7
        case .inboxResponseDecodeFailed: return 8
        }
    }
}
