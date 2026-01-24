//
//  Inbox.swift
//  attentive-ios-sdk
//
//  Created by Umair Sharif on 1/15/26.
//

import Combine
import Foundation

public actor Inbox {
    private var messages: [Message.ID: Message]

    private nonisolated(unsafe) let messagesSubject: CurrentValueSubject<[Message], Never>

    public nonisolated var allMessagesPublisher: AnyPublisher<[Message], Never> {
        messagesSubject.eraseToAnyPublisher()
    }

    public var allMessages: [Message] {
        Array(messages.values)
    }

    public var unreadCount: Int {
        messages.filter {
            !$0.value.isRead
        }.count
    }

    public init(messages: [Message.ID: Message] = [:]) {
        self.messages = messages
        self.messagesSubject = CurrentValueSubject(Array(messages.values))
    }

    public func updateMessages(_ newMessages: [Message.ID: Message]) {
        self.messages = newMessages
        messagesSubject.send(Array(newMessages.values))
    }

    public func markRead(_ messageID: Message.ID) {
        messages[messageID]?.isRead = true
        messagesSubject.send(Array(messages.values))
    }

    public func markUnread(_ messageID: Message.ID) {
        messages[messageID]?.isRead = false
        messagesSubject.send(Array(messages.values))
    }

    public func delete(_ messageID: Message.ID) {
        messages.removeValue(forKey: messageID)
        messagesSubject.send(Array(messages.values))
    }
}
