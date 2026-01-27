//
//  Inbox.swift
//  attentive-ios-sdk
//
//  Created by Umair Sharif on 1/15/26.
//

import Foundation

public enum InboxState: Sendable {
    case loading
    case loaded([Message])
    case error(Error)
}

actor Inbox {
    private var messagesByID: [Message.ID: Message] = [:]
    private var cachedSortedMessages: [Message]?
    private var currentState: InboxState = .loading
    private var continuations: [UUID: AsyncStream<InboxState>.Continuation] = [:]

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

    /// Returns an AsyncStream that immediately emits the current state,
    /// then emits all subsequent state changes.
    var stateStream: AsyncStream<InboxState> {
        let currentState = self.currentState
        return AsyncStream { continuation in
            let id = UUID()
            // Emit current state immediately
            continuation.yield(currentState)

            // Register for future updates
            self.continuations[id] = continuation

            continuation.onTermination = { [weak self] _ in
                Task { [weak self] in
                    await self?.removeContinuation(id: id)
                }
            }
        }
    }

    init() {
        Task {
            await send(.loading)
            await updateMessages(Self.getMockMessages())
        }
    }

    func markRead(_ messageID: Message.ID) {
        messagesByID[messageID]?.isRead = true
        updateCachedMessage(messageID)
        send(.loaded(allMessages))
    }

    func markUnread(_ messageID: Message.ID) {
        messagesByID[messageID]?.isRead = false
        updateCachedMessage(messageID)
        send(.loaded(allMessages))
    }

    func delete(_ messageID: Message.ID) {
        messagesByID.removeValue(forKey: messageID)
        invalidateCache()
        send(.loaded(allMessages))
    }

    func refresh() async {
        await updateMessages(Self.getMockMessages())
    }
}

// MARK: - Private methods

extension Inbox {
    private func removeContinuation(id: UUID) {
        continuations.removeValue(forKey: id)
    }

    private func send(_ state: InboxState) {
        currentState = state
        for continuation in continuations.values {
            continuation.yield(state)
        }
    }

    private func updateMessages(_ messages: [Message]) {
        messagesByID = messages.reduce(into: [Message.ID: Message]()) {
            $0[$1.id] = $1
        }
        invalidateCache()
        send(.loaded(allMessages))
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
                timestamp: Date().advanced(by: -86400),
                isRead: false,
                imageURLString: "https://picsum.photos/200"
            ),
            Message(
                id: "2",
                title: "New Sale Alert",
                body: "50% off on all items this weekend!",
                timestamp: Date().advanced(by: -172800),
                isRead: false,
                imageURLString: "https://picsum.photos/200"
            ),
            Message(
                id: "3",
                title: "Your Order Has Shipped",
                body: "Your order #12345 is on its way!",
                timestamp: Date().advanced(by: -259200),
                isRead: false,
                actionURLString: "https://example.com/track/12345"
            )
        ]
    }
}
