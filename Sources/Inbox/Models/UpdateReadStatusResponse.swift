//
//  UpdateReadStatusResponse.swift
//  attentive-ios-sdk
//

import Foundation

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
