//
//  InboxManager.swift
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

/// Closure that supplies the identifiers needed to call the inbox endpoints.
/// Resolved at call-time so the manager always uses the latest values from `ATTNSDK`.
typealias InboxIdentityProvider = @Sendable () -> (userIdentity: ATTNUserIdentity, pushToken: String, email: String?, phone: String?)

actor InboxManager {
    private var messagesByID: [Message.ID: Message] = [:]
    private var cachedSortedMessages: [Message]?
    private var currentState: InboxState = .loading
    private var continuations: [UUID: AsyncStream<InboxState>.Continuation] = [:]

    /// Server-authoritative unread count. Updated only by `refreshUnreadCount()` and (future)
    /// mark-read/mark-unread/delete API responses — local `markRead`/`markUnread` mutations
    /// do not change this value.
    private(set) var unreadCount: Int = 0

    private let api: ATTNAPIProtocol?
    private let identityProvider: InboxIdentityProvider?

    var allMessages: [Message] {
        if let cached = cachedSortedMessages {
            return cached
        }
        let sorted = messagesByID.values.sorted { $0.timestamp > $1.timestamp }
        cachedSortedMessages = sorted
        return sorted
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

    init(api: ATTNAPIProtocol? = nil, identityProvider: InboxIdentityProvider? = nil) {
        self.api = api
        self.identityProvider = identityProvider
        Task {
            await send(.loading)
            // Run mock-message load and unread-count fetch concurrently — they touch
            // independent state and the network call should not wait on the local mock.
            async let messages: Void = updateMessages(Self.getMockInbox().messages)
            async let count: Void = refreshUnreadCount()
            _ = await (messages, count)
        }
    }

    /// Fetches the latest unread count from the server and stores it as the
    /// authoritative value. Errors are logged; the previously stored count is preserved.
    func refreshUnreadCount() async {
        print("[MSDK-377] InboxManager.refreshUnreadCount() entered")
        guard let api = api, let identityProvider = identityProvider else {
            Loggers.network.debug("Skipping refreshUnreadCount — no API or identity provider configured")
            print("[MSDK-377] ⚠️ skipped: api=\(api == nil ? "nil" : "set") identityProvider=\(identityProvider == nil ? "nil" : "set")")
            return
        }

        let (userIdentity, pushToken, email, phone) = identityProvider()
        do {
            unreadCount = try await api.fetchInboxUnreadCount(
                pushToken: pushToken,
                email: email,
                phone: phone,
                userIdentity: userIdentity
            )
            print("[MSDK-377] InboxManager.unreadCount updated to \(unreadCount)")
            // Re-emit current state so observers re-read the updated `unreadCount`.
            // The state value itself is unchanged; this is a nudge for badge UIs.
            send(currentState)
        } catch {
            Loggers.network.error("Failed to refresh inbox unread count: \(error.localizedDescription, privacy: .public)")
            print("[MSDK-377] ❌ refreshUnreadCount error: \(error.localizedDescription)")
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
        await updateMessages(Self.getMockInbox().messages)
    }
}

// MARK: - Private methods

extension InboxManager {
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

fileprivate extension InboxManager {
    private static func getMockInbox() async -> InboxResponse {
        #warning("Artificial delay to simulate delayed network response, should be removed in production.")
        try? await Task.sleep(nanoseconds: 2000000000)
        let messages: [Message] = [
            Message(
                id: "1",
                style: .small,
                title: "Welcome to Attentive!",
                body: "Thanks for joining us. Check out our latest offers.",
                timestamp: Date().advanced(by: -86400),
                isRead: false,
                imageURLString: "https://picsum.photos/200"
            ),
            Message(
                id: "2",
                style: .large,
                title: "New Sale Alert",
                body: "50% off on all items this weekend!",
                timestamp: Date().advanced(by: -172800),
                isRead: false,
                imageURLString: "https://picsum.photos/200/120"
            ),
            Message(
                id: "3",
                style: .small,
                title: "Your Order Has Shipped",
                body: "Your order #12345 is on its way!",
                timestamp: Date().advanced(by: -259200),
                isRead: false,
                actionURLString: "https://example.com/track/12345"
            )
        ]
        return InboxResponse(messages: messages, unreadCount: 2)
    }
}
