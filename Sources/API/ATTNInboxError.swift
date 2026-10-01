//
//  ATTNInboxError.swift
//  attentive-ios-sdk-framework
//

import Foundation

/// Errors from the inbox API, surfaced through `InboxState.error(_:)`.
///
/// Deliberately separate from `ATTNError`: adding cases to that shipped public enum would break
/// host apps that switch over it exhaustively.
public enum ATTNInboxError: Error, Equatable {
    case requestFailed(statusCode: Int)
    case responseDecodeFailed
}

extension ATTNInboxError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .requestFailed(let statusCode):
            return "Inbox request failed with status code \(statusCode)"
        case .responseDecodeFailed:
            return "Failed to decode inbox response"
        }
    }
}

extension ATTNInboxError: CustomNSError {
    public static var errorDomain: String { "com.attentive.sdk.inbox" }

    public var errorCode: Int {
        switch self {
        case .requestFailed: return 1
        case .responseDecodeFailed: return 2
        }
    }
}
