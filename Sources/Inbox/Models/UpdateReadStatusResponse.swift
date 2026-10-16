//
//  UpdateReadStatusResponse.swift
//  attentive-ios-sdk
//

import Foundation

/// Request body shared by the mark-read (`PATCH /inbox/messages/read`) and mark-unread
/// (`PATCH /inbox/messages/unread`) endpoints. `pushToken` is optional so an empty token is
/// omitted from the wire payload rather than sent as `""`. `clientDomainPrefix` (`c`) is
/// required by the server for company resolution — a blank value returns 400.
struct UpdateReadStatusRequest: Encodable {
    let clientDomainPrefix: String
    let visitorId: String
    let pushToken: String?
    let messageIds: [String]

    enum CodingKeys: String, CodingKey {
        case clientDomainPrefix = "c"
        case visitorId = "visitor_id"
        case pushToken = "push_token"
        case messageIds = "message_ids"
    }
}

struct UpdateReadStatusResponse: Codable {
    struct MessageReadStatus: Codable {
        let messageId: String
        let isRead: Bool

        enum CodingKeys: String, CodingKey {
            case messageId = "message_id"
            case isRead = "is_read"
        }
    }

    let messages: [MessageReadStatus]
    let unreadCount: Int

    enum CodingKeys: String, CodingKey {
        case messages
        case unreadCount = "unread_count"
    }
}
