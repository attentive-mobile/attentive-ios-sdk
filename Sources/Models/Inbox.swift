//
//  Inbox.swift
//  attentive-ios-sdk
//
//  Created by Umair Sharif on 1/15/26.
//

import Combine
import Foundation

public enum InboxState {
    case loading
    case loaded([Message])
    case error(Error)
}

actor Inbox {
    private var messagesByID: [Message.ID: Message] = [:]
    private var cachedSortedMessages: [Message]?

    private nonisolated let stateSubject = CurrentValueSubject<InboxState, Never>(.loading)

    nonisolated var statePublisher: AnyPublisher<InboxState, Never> {
        stateSubject.eraseToAnyPublisher()
    }

    var allMessages: [Message] {
        if let cached = cachedSortedMessages {
            return cached
        }
        let sorted = messagesByID.values.sorted { $0.timestamp > $1.timestamp }
        cachedSortedMessages = sorted
        return sorted
    }

    var unreadCount: Int {
        messagesByID.values.filter { !$0.isRead }.count
    }

    init() {
        Task {
            await updateMessages(Self.getMockMessages())
        }
    }

    func markRead(_ messageID: Message.ID) {
        messagesByID[messageID]?.isRead = true
        updateCachedMessage(messageID)
        stateSubject.send(.loaded(allMessages))
    }

    func markUnread(_ messageID: Message.ID) {
        messagesByID[messageID]?.isRead = false
        updateCachedMessage(messageID)
        stateSubject.send(.loaded(allMessages))
    }

    func delete(_ messageID: Message.ID) {
        messagesByID.removeValue(forKey: messageID)
        invalidateCache()
        stateSubject.send(.loaded(allMessages))
    }

    func refresh() async {
        await updateMessages(Self.getMockMessages())
    }

    private func updateMessages(_ messages: [Message]) {
        messagesByID = messages.reduce(into: [Message.ID: Message]()) {
            $0[$1.id] = $1
        }
        invalidateCache()
        stateSubject.send(.loaded(allMessages))
    }

    private func invalidateCache() {
        cachedSortedMessages = nil
    }

    private func updateCachedMessage(_ messageID: Message.ID) {
        let cachedSortedMessageIndex = messagesByID[messageID].flatMap { message in
            cachedSortedMessages?.firstIndex { cachedMessage in
                cachedMessage.id == message.id
            }
        }
        guard let updatedMessage = messagesByID[messageID], let cachedSortedMessageIndex else {
            return
        }
        cachedSortedMessages?[cachedSortedMessageIndex] = updatedMessage
    }
}

fileprivate extension Inbox {
    private static func getMockMessages() async -> [Message] {
        #warning("Artificial delay to simulate delayed network response, should be removed in production.")
        try? await Task.sleep(nanoseconds: 2000000000)
        return [
            Message(
                id: "1",
                title: "Welcome to Attentive!",
                body: "Thanks for joining us. Check out our latest offers.",
                timestamp: Date().advanced(by: -86400000),
                isRead: false,
                imageURLString: "https://picsum.photos/200"
            ),
            Message(
                id: "2",
                title: "New Sale Alert",
                body: "50% off on all items this weekend!",
                timestamp: Date().advanced(by: -172800000),
                isRead: false,
                imageURLString: "https://picsum.photos/200"
            ),
            Message(
                id: "3",
                title: "Your Order Has Shipped",
                body: "Your order #12345 is on its way!",
                timestamp: Date().advanced(by: -259200000),
                isRead: false,
                actionURLString: "https://example.com/track/12345"
            )
        ]
    }
}
