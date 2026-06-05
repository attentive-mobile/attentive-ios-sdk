//
//  InboxUnreadCountResponse.swift
//  attentive-ios-sdk
//
//  Created by Adela Gao on 6/4/26.
//

struct InboxUnreadCountResponse: Codable {
    let unreadCount: Int

    enum CodingKeys: String, CodingKey {
        case unreadCount = "unread_count"
    }
}
