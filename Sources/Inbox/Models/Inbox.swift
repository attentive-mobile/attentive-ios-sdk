//
//  Inbox.swift
//  attentive-ios-sdk
//
//  Created by Umair Sharif on 2/2/26.
//

struct Inbox: Codable {
    var messages: [Message]
    var unreadCount: Int
}
