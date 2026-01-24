//
//  Inbox.swift
//  attentive-ios-sdk
//
//  Created by Umair Sharif on 1/15/26.
//

import Combine
import Foundation

actor Inbox {
    private var messagesByID: [Message.ID: Message] = [:]

    private nonisolated(unsafe) let messagesSubject = CurrentValueSubject<[Message], Never>([])

    nonisolated var allMessagesPublisher: AnyPublisher<[Message], Never> {
        messagesSubject.eraseToAnyPublisher()
    }

    var allMessages: [Message] {
        Array(messagesByID.values)
    }

    var unreadCount: Int {
        messagesByID.filter {
            !$0.value.isRead
        }.count
    }

    func updateMessages(_ messages: [Message]) {
        self.messagesByID = messages.reduce(into: [Message.ID: Message]()) {
            $0[$1.id] = $1
        }
        messagesSubject.send(messages)
    }

    func markRead(_ messageID: Message.ID) {
        messagesByID[messageID]?.isRead = true
        messagesSubject.send(Array(messagesByID.values))
    }

    func markUnread(_ messageID: Message.ID) {
        messagesByID[messageID]?.isRead = false
        messagesSubject.send(Array(messagesByID.values))
    }

    func delete(_ messageID: Message.ID) {
        messagesByID.removeValue(forKey: messageID)
        messagesSubject.send(Array(messagesByID.values))
    }
}
