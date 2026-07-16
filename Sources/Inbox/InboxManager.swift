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
    /// Per RFC, the server clamps `page_size` to its own upper bound; this value is a client-side
    /// hint that balances first-paint latency against round-trip count.
    private static let defaultPageSize = 20

    private var messagesByID: [Message.ID: Message] = [:]
    private var messageOrder: [Message.ID] = []
    private var currentState: InboxState = .loading
    private var continuations: [UUID: AsyncStream<InboxState>.Continuation] = [:]

    /// Cursor from the most recent successful page fetch. `nil` means "no more pages" (or "haven't
    /// fetched yet"); use `hasMore` for the caller-facing "can we page further" signal.
    private var nextPageToken: String?
    private var hasFetchedFirstPage: Bool = false
    /// Guards against overlapping `loadNextPage()` calls when the SwiftUI list rapidly reports
    /// the last row appearing.
    private var isLoadingNextPage: Bool = false

    /// Server-authoritative unread count. Only `refreshUnreadCount()` writes it; local
    /// `markRead` / `markUnread` do not. Reads should go through the `unreadCount` accessor,
    /// which awaits the init-time refresh so the first read never returns a stale 0.
    private var storedUnreadCount: Int = 0

    private let api: ATTNAPIProtocol
    private let identityProvider: InboxIdentityProvider

    /// Drained exactly once by `awaitInitialRefresh()` before the first `unreadCount` /
    /// `allMessages` read returns.
    private var initialRefreshTask: Task<Void, Never>?

    /// Monotonic counter used to discard responses from unread-count fetches that have been
    /// superseded by a newer in-flight call or an identity reset.
    private var refreshGeneration: UInt = 0

    /// Monotonic counter used to discard responses from message refresh/pagination calls that
    /// have been superseded by a newer identity or a newer top-level `refresh()`.
    private var messagesGeneration: UInt = 0

    var allMessages: [Message] {
        get async {
            await awaitInitialRefresh()
            return orderedMessagesSnapshot()
        }
    }

    var unreadCount: Int {
        get async {
            await awaitInitialRefresh()
            return storedUnreadCount
        }
    }

    /// True when the last successful fetch reported a `next_page_token`. Used by tests and any
    /// caller that wants a cheap "can we page further" signal without calling `loadNextPage()`.
    var hasMore: Bool {
        nextPageToken?.isEmpty == false
    }

    /// Test-only accessor for the current state, since we can't read `currentState` directly.
    var currentInboxStateForTesting: InboxState {
        currentState
    }

    private func awaitInitialRefresh() async {
        // Drain the init-time refresh exactly once; subsequent reads are constant-time.
        if let task = initialRefreshTask {
            await task.value
            initialRefreshTask = nil
        }
    }

    /// Returns an AsyncStream that immediately emits the current state,
    /// then emits all subsequent state changes.
    var stateStream: AsyncStream<InboxState> {
        let currentState = self.currentState
        return AsyncStream { continuation in
            let id = UUID()
            continuation.yield(currentState)
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
        // Fetch the first page of messages and the unread count on construction so passive-badge
        // hosts (`sdk.unreadCount`) and stream/`allMessages` consumers both resolve without
        // needing to present `inboxView()`. Non-inbox hosts never construct the manager — see
        // `ATTNSDK.materializedInboxManager()`. Calls `performUnreadCountFetch` directly (not
        // `refreshUnreadCount`) so it doesn't try to coalesce with itself.
        initialRefreshTask = Task { [weak self] in
            await self?.performMessagesAndUnreadCountRefresh()
        }
    }

    /// Fetches the first page of inbox messages and the latest unread count, replacing any
    /// previously loaded messages. The two fetches run concurrently. Callers should invoke
    /// this on inbox open / pull-to-refresh / push open.
    func refresh() async {
        await performMessagesAndUnreadCountRefresh()
    }

    /// Fetches the next page of messages using the stored `nextPageToken` and appends them.
    /// Safe to call repeatedly — no-ops when no more pages are available or another fetch is in flight.
    /// Returns `true` when a network fetch was actually started; callers can use this to gate a
    /// "loading more" indicator without needing a separate probe.
    @discardableResult
    func loadNextPage() async -> Bool {
        guard hasFetchedFirstPage, !isLoadingNextPage, let pageToken = nextPageToken, !pageToken.isEmpty else {
            return false
        }
        let identity = identityProvider()
        guard !identity.visitorId.isEmpty else { return false }

        isLoadingNextPage = true
        let generation = messagesGeneration

        do {
            let response = try await api.fetchInboxMessages(
                pushToken: identity.pushToken,
                email: identity.email,
                phone: identity.phone,
                visitorId: identity.visitorId,
                pageSize: Self.defaultPageSize,
                pageToken: pageToken
            )
            guard generation == messagesGeneration else {
                // Identity or refresh() moved on; discard this page.
                isLoadingNextPage = false
                return true
            }
            appendMessages(response.messages)
            nextPageToken = response.nextPageToken
            isLoadingNextPage = false
            send(.loaded(orderedMessagesSnapshot()))
        } catch {
            Loggers.network.error("Failed to load next inbox page: \(error.localizedDescription, privacy: .public)")
            isLoadingNextPage = false
            // Keep existing list; caller can retry by pulling up again.
        }
        return true
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

    /// Fetches the first page of messages and the server-authoritative unread count concurrently.
    /// Shared by init-time load and every `refresh()`. `skipNotify: false` lets subscribers get a
    /// nudge to re-read `unreadCount` when the count arrives after the messages have already
    /// emitted `.loaded` (order between the two `async let`s is non-deterministic).
    private func performMessagesAndUnreadCountRefresh() async {
        async let messages: Void = performMessagesRefresh()
        async let count: Void = performUnreadCountFetch(skipNotify: false)
        _ = await (messages, count)
    }

    /// Internal worker used by both the init task and the public `refresh()`. Fetches page 1,
    /// resets pagination bookkeeping, and updates state.
    private func performMessagesRefresh() async {
        let identity = identityProvider()
        guard !identity.visitorId.isEmpty else {
            Loggers.network.debug("Skipping inbox messages refresh: empty visitor ID")
            return
        }

        messagesGeneration &+= 1
        let generation = messagesGeneration
        // Cancel any in-flight page load; the bumped generation will make it a no-op on return.
        isLoadingNextPage = false

        // Only emit .loading on the very first refresh; on subsequent refreshes keep the last
        // successful list visible until the new page arrives, mirroring iOS Mail behavior.
        if !hasFetchedFirstPage {
            send(.loading)
        }

        do {
            let response = try await api.fetchInboxMessages(
                pushToken: identity.pushToken,
                email: identity.email,
                phone: identity.phone,
                visitorId: identity.visitorId,
                pageSize: Self.defaultPageSize,
                pageToken: nil
            )
            guard generation == messagesGeneration else { return }
            replaceMessages(with: response.messages)
            nextPageToken = response.nextPageToken
            hasFetchedFirstPage = true
            send(.loaded(orderedMessagesSnapshot()))
        } catch {
            guard generation == messagesGeneration else { return }
            Loggers.network.error("Failed to refresh inbox messages: \(error.localizedDescription, privacy: .public)")
            // Preserve the previously loaded list and its pagination cursor on error; only
            // surface `.error` if we never successfully loaded anything.
            if hasFetchedFirstPage {
                send(.loaded(orderedMessagesSnapshot()))
            } else {
                send(.error(error))
            }
        }
    }

    /// Internal worker. Always fires a network request — no coalesce check — so the init
    /// task can call this without deadlocking on itself. `skipNotify == true` when the
    /// caller (e.g. `refresh()`) will emit its own `.loaded` after updating messages.
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
        guard messagesByID[messageID]?.isRead == false else { return }
        messagesByID[messageID]?.isRead = true
        send(.loaded(orderedMessagesSnapshot()))
    }

    func markUnread(_ messageID: Message.ID) {
        guard messagesByID[messageID]?.isRead == true else { return }
        messagesByID[messageID]?.isRead = false
        send(.loaded(orderedMessagesSnapshot()))
    }

    func delete(_ messageID: Message.ID) {
        messagesByID.removeValue(forKey: messageID)
        messageOrder.removeAll { $0 == messageID }
        send(.loaded(orderedMessagesSnapshot()))
    }

    /// Clears all cached inbox state (messages, unread count, pagination cursor) and bumps both
    /// generations so any in-flight fetches from the previous identity are discarded when they
    /// return. Called on identity changes (`clearUser`, `updateUser`) so a logged-out account's
    /// messages and badge are not surfaced to the next user.
    func resetForIdentityChange() {
        refreshGeneration &+= 1
        messagesGeneration &+= 1
        storedUnreadCount = 0
        messagesByID = [:]
        messageOrder = []
        nextPageToken = nil
        hasFetchedFirstPage = false
        isLoadingNextPage = false
        // Only re-emit when we were already surfacing a loaded list — never override an
        // in-flight .loading state, which would strand hosts that don't re-present InboxView.
        if case .loaded = currentState {
            send(.loaded([]))
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

    private func orderedMessagesSnapshot() -> [Message] {
        messageOrder.compactMap { messagesByID[$0] }
    }

    private func replaceMessages(with messages: [Message]) {
        messagesByID = [:]
        messageOrder = []
        appendMessages(messages)
    }

    private func appendMessages(_ messages: [Message]) {
        // Dedup on id; the server's contract is stable per (companyId, userId, messageId) but a
        // retried page during a paginated fetch could still deliver a duplicate.
        for message in messages where messagesByID[message.id] == nil {
            messagesByID[message.id] = message
            messageOrder.append(message.id)
        }
    }
}
