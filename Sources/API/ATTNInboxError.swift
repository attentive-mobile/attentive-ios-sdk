//
//  ATTNInboxError.swift
//  attentive-ios-sdk-framework
//

import Foundation

/// Inbox-specific failures, surfaced through `InboxState.error(_:)`. Not every inbox error is an
/// `ATTNInboxError`: bad URLs still surface as `ATTNError.badURL`, and transport (`URLError`) and
/// request-encoding errors propagate unchanged.
///
/// Deliberately separate from `ATTNError`: adding cases to that shipped public enum would break
/// host apps that switch over it exhaustively.
public enum ATTNInboxError: Error, Equatable {
    /// The server answered with a non-2xx status code.
    case requestFailed(statusCode: Int)
    /// The response body couldn't be decoded into the expected model.
    case responseDecodeFailed
    /// The response wasn't an HTTP response, so it was rejected before any decoding.
    case unexpectedResponseType
}

extension ATTNInboxError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .requestFailed(let statusCode):
            return "Inbox request failed with status code \(statusCode)"
        case .responseDecodeFailed:
            return "Failed to decode inbox response"
        case .unexpectedResponseType:
            return "Inbox request returned an unexpected response type"
        }
    }
}

extension ATTNInboxError: CustomNSError {
    public static var errorDomain: String { "com.attentive.sdk.inbox" }

    public var errorCode: Int {
        switch self {
        case .requestFailed: return 1
        case .responseDecodeFailed: return 2
        case .unexpectedResponseType: return 3
        }
    }
}
