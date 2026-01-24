//
//  Inbox.swift
//  attentive-ios-sdk
//
//  Created by Umair Sharif on 1/15/26.
//

import Combine
import Foundation

public class Inbox: ObservableObject {
    @Published
    public var messages: [Message.ID: Message]
    public var unreadCount: Int {
        messages.filter {
            !$0.value.isRead
        }.count
    }

    public init(messages: [Message.ID: Message] = [:]) {
        self.messages = messages
    }
}
