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

/// Identifiers needed to call the inbox endpoints.
struct InboxIdentitySnapshot: Sendable {
    let visitorId: String
    let pushToken: String
    let email: String?
    let phone: String?
}

/// Closure that supplies the identifiers needed to call the inbox endpoints.
/// Resolved at call-time so the manager always uses the latest values from `ATTNSDK`.
typealias InboxIdentityProvider = @Sendable () -> InboxIdentitySnapshot

actor InboxManager {
    private var messagesByID: [Message.ID: Message] = [:]
    private var cachedSortedMessages: [Message]?
    private var currentState: InboxState = .loading
    private var continuations: [UUID: AsyncStream<InboxState>.Continuation] = [:]

    /// Server-authoritative unread count. Only `refreshUnreadCount()` writes it; local
    /// `markRead` / `markUnread` do not. Reads should go through the `unreadCount` accessor,
    /// which awaits the init-time refresh so the first read never returns a stale 0.
    private var storedUnreadCount: Int = 0

    private let api: ATTNAPIProtocol
    private let identityProvider: InboxIdentityProvider

    /// Drained exactly once by `awaitInitialRefresh()` before the first `unreadCount` /
    /// `allMessages` read returns.
    private var initialRefreshTask: Task<Void, Never>?

    /// Monotonic counter used to discard responses from refresh calls that have been
    /// superseded by a newer in-flight call or an identity reset.
    private var refreshGeneration: UInt = 0

    var allMessages: [Message] {
        get async {
            await awaitInitialRefresh()
            return sortedMessagesSnapshot()
        }
    }

    var unreadCount: Int {
        get async {
            await awaitInitialRefresh()
            return storedUnreadCount
        }
    }

    private func awaitInitialRefresh() async {
        // Drain the init-time refresh exactly once; subsequent reads are constant-time.
        if let task = initialRefreshTask {
            await task.value
            initialRefreshTask = nil
        }
    }

    private func sortedMessagesSnapshot() -> [Message] {
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

    init(api: ATTNAPIProtocol, identityProvider: @escaping InboxIdentityProvider) {
        self.api = api
        self.identityProvider = identityProvider
        // Passive-badge hosts read `sdk.unreadCount` without opening the inbox surface, so
        // the manager fetches on construction. Non-inbox hosts never construct it — see
        // `ATTNSDK.materializedInboxManager()`.
        // The init task calls `performUnreadCountFetch` directly (not `refreshUnreadCount`)
        // so it doesn't try to coalesce with itself.
        initialRefreshTask = Task { [weak self] in
            await self?.performUnreadCountFetch(skipNotify: false)
        }
    }

    /// Fetches the latest unread count from the server and stores it as the
    /// authoritative value. Errors are logged; the previously stored count is preserved.
    /// If multiple refreshes are in flight, only the most recently issued one is honored.
    func refreshUnreadCount() async {
        // Coalesce with the init-time fetch. A host that follows the RFC and calls
        // `refreshInboxUnreadCount()` on app launch would otherwise race the manager's own
        // init fetch and produce two identical POSTs.
        if let task = initialRefreshTask {
            initialRefreshTask = nil
            await task.value
            return
        }
        await performUnreadCountFetch(skipNotify: false)
    }

    /// Internal worker. Always fires a network request — no coalesce check — so the init
    /// task can call this without deadlocking on itself. `skipNotify == true` when the
    /// caller (e.g. `refresh()`) will emit its own `.loaded` after `updateMessages`.
    private func performUnreadCountFetch(skipNotify: Bool) async {
        let identity = identityProvider()
        // Without a visitor ID the server can't scope the request — skip rather than send
        // an unscoped call that would 4xx and pollute logs.
        guard !identity.visitorId.isEmpty else {
            Loggers.network.debug("Skipping inbox unread count refresh: empty visitor ID")
            return
        }
        refreshGeneration &+= 1
        let generation = refreshGeneration
        do {
            let count = try await api.fetchInboxUnreadCount(
                pushToken: identity.pushToken,
                email: identity.email,
                phone: identity.phone,
                visitorId: identity.visitorId
            )
            // Drop superseded responses so a slow earlier call cannot overwrite a fresher one.
            guard generation == refreshGeneration else { return }
            let previous = storedUnreadCount
            storedUnreadCount = count
            // Re-emit only when the value actually changed and we're in a loaded state — avoids
            // waking subscribers with an identical payload on every no-op refresh.
            if !skipNotify, count != previous, case .loaded = currentState {
                send(currentState)
            }
        } catch {
            Loggers.network.error("Failed to refresh inbox unread count: \(error.localizedDescription, privacy: .public)")
        }
    }

    func markRead(_ messageID: Message.ID) {
        messagesByID[messageID]?.isRead = true
        updateCachedMessage(messageID)
        send(.loaded(sortedMessagesSnapshot()))
    }

    func markUnread(_ messageID: Message.ID) {
        messagesByID[messageID]?.isRead = false
        updateCachedMessage(messageID)
        send(.loaded(sortedMessagesSnapshot()))
    }

    func delete(_ messageID: Message.ID) {
        messagesByID.removeValue(forKey: messageID)
        invalidateCache()
        send(.loaded(sortedMessagesSnapshot()))
    }

    /// Reloads inbox messages and re-fetches the server-authoritative unread count.
    /// Called on inbox open, pull-to-refresh, and (indirectly, via the host app) push open.
    /// Once the real messages endpoint replaces `getMockInbox()` this should switch to
    /// `async let` so the two network calls run concurrently.
    func refresh() async {
        updateMessages(Self.getMockInbox().messages)
        // skipNotify because updateMessages above already emitted `.loaded`.
        await performUnreadCountFetch(skipNotify: true)
    }

    /// Resets the cached unread count to 0 and bumps the refresh generation so any in-flight
    /// fetch from the previous identity is discarded when it returns. Called on identity changes
    /// (`clearUser`, `updateUser`) so a logged-out account's badge is not surfaced to the next user.
    func resetUnreadCount() {
        refreshGeneration &+= 1
        guard storedUnreadCount != 0 else { return }
        storedUnreadCount = 0
        if case .loaded = currentState {
            send(currentState)
        }
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
        send(.loaded(sortedMessagesSnapshot()))
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
    private static func getMockInbox() -> InboxResponse {
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
        return InboxResponse(messages: messages)
    }
}
