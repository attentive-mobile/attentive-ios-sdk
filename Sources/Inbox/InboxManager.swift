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
    /// Broadcasts every `isLoadingNextPage` transition so the ViewModel can render a footer
    /// spinner that tracks the manager's true fetch state, not an optimistic guess.
    private var loadingMoreContinuations: [UUID: AsyncStream<Bool>.Continuation] = [:]

    /// Cursor from the most recent successful page fetch. `nil` means "no more pages" (or "haven't
    /// fetched yet"); use `hasMore` for the caller-facing "can we page further" signal.
    private var nextPageToken: String?
    private var hasFetchedFirstPage: Bool = false
    /// Guards against overlapping `loadNextPage()` calls when the SwiftUI list rapidly reports
    /// the last row appearing.
    private var isLoadingNextPage: Bool = false
    /// Set while a first-page refresh is in flight. `loadNextPage()` refuses to run during this
    /// window: without the gate, a page load fired mid-refresh (e.g. last-row `.onAppear` during
    /// a pull-to-refresh) would pass the guard, capture the refresh's generation, and clobber
    /// `nextPageToken` when both settle. Distinct from `isLoadingNextPage` because a stale page
    /// load returning inside the refresh window resets that flag but must not release this one.
    private var isRefreshingFirstPage: Bool = false

    /// Server-authoritative unread count. Written by `refreshUnreadCount()` and by the mark-read /
    /// mark-unread API responses (see `applyReadStatusResponse`). Reads should go through the
    /// `unreadCount` accessor, which awaits the init-time refresh so the first read never returns
    /// a stale 0.
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

    /// Monotonic counter bumped every time the messages list is wholesale replaced from an
    /// authoritative source (successful refresh or identity reset). Distinct from
    /// `messagesGeneration`, which bumps at the *start* of a refresh — so a refresh that fails
    /// mid-DELETE would bump `messagesGeneration` but not `messagesReplacedCount`, and the
    /// delete's revert path should still apply. Read only by `delete(_:)` for that reason.
    private var messagesReplacedCount: UInt = 0

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

    /// Returns an AsyncStream that immediately emits the current `isLoadingNextPage`, then
    /// emits every subsequent transition. Distinct from `stateStream` so a paging-in-flight
    /// signal doesn't force the list to re-render just because a footer spinner is (dis)appearing.
    var loadingMoreStream: AsyncStream<Bool> {
        let current = self.isLoadingNextPage
        return AsyncStream { continuation in
            let id = UUID()
            continuation.yield(current)
            self.loadingMoreContinuations[id] = continuation
            continuation.onTermination = { [weak self] _ in
                Task { [weak self] in
                    await self?.removeLoadingMoreContinuation(id: id)
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
        // Coalesce with the init-time fetch. `InboxView.task` fires immediately after
        // materializing the manager, so without this the first open would double-POST and race
        // its own init generation.
        if let task = initialRefreshTask {
            initialRefreshTask = nil
            await task.value
            return
        }
        await performMessagesAndUnreadCountRefresh()
    }

    /// Fetches the next page of messages using the stored `nextPageToken` and appends them.
    /// Safe to call repeatedly — no-ops when no more pages are available, another fetch is in
    /// flight, or a first-page refresh is running. Subscribers to `loadingMoreStream` observe
    /// the in-flight state; callers do not need to inspect a return value.
    func loadNextPage() async {
        guard hasFetchedFirstPage,
              !isRefreshingFirstPage,
              !isLoadingNextPage,
              let pageToken = nextPageToken,
              !pageToken.isEmpty else {
            return
        }
        guard let identity = requireIdentity(context: "inbox page load") else { return }

        setLoadingNextPage(true)
        let generation = messagesGeneration
        // Guard the release on generation: a superseded page load returning after a newer
        // refresh or another page load has bumped the counter must not clear the newer one's
        // flag (would prematurely hide the spinner and re-open the guard for a duplicate fetch).
        defer {
            if generation == messagesGeneration {
                setLoadingNextPage(false)
            }
        }

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
                return
            }
            appendMessages(response.messages)
            nextPageToken = response.nextPageToken
            send(.loaded(orderedMessagesSnapshot()))
        } catch {
            Loggers.network.error("Failed to load next inbox page: \(error.localizedDescription, privacy: .public)")
            // Keep existing list; caller can retry by pulling up again.
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
        guard let identity = requireIdentity(context: "inbox messages refresh") else { return }

        messagesGeneration &+= 1
        let generation = messagesGeneration
        // Cancel any in-flight page load; the bumped generation will make it a no-op on return.
        setLoadingNextPage(false)
        // Block new page loads for the duration of this refresh — even one that fires between
        // now and when the page-1 response arrives would otherwise race the refresh and clobber
        // the fresh `nextPageToken` with a stale one.
        isRefreshingFirstPage = true
        // Guard the release on generation: if a newer refresh (or `resetForIdentityChange`)
        // bumps the counter, it owns the flag and manages release itself — a superseded
        // refresh clearing the gate would re-open the exact race this flag exists to prevent.
        defer {
            if generation == messagesGeneration {
                isRefreshingFirstPage = false
            }
        }

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
        guard let identity = requireIdentity(context: "inbox unread count refresh") else { return }
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

    /// Marks a message read. Optimistically flips the local state, then reconciles from the
    /// server response. On failure the local flip is reverted so the UI reflects true state.
    func markRead(_ messageID: Message.ID) async {
        guard let previousIsRead = messagesByID[messageID]?.isRead else { return }

        guard let identity = requireIdentity(context: "inbox mark-read") else { return }

        if !previousIsRead {
            messagesByID[messageID]?.isRead = true
            send(.loaded(orderedMessagesSnapshot()))
        }

        // Snapshot the refresh generation before the request. If an identity change
        // (`resetForIdentityChange`) or a newer `refreshUnreadCount` lands while the PATCH is in
        // flight, the generation advances and we drop this now-stale response instead of
        // restoring an old unread count.
        let generation = refreshGeneration

        do {
            let response = try await api.markMessagesRead(
                pushToken: identity.pushToken,
                visitorId: identity.visitorId,
                messageIds: [messageID]
            )
            guard generation == refreshGeneration else { return }
            applyReadStatusResponse(response)
        } catch {
            Loggers.network.error("Failed to mark inbox message read: \(error.localizedDescription, privacy: .public)")
            guard generation == refreshGeneration else { return }
            if messagesByID[messageID] != nil, !previousIsRead {
                messagesByID[messageID]?.isRead = previousIsRead
                send(.loaded(orderedMessagesSnapshot()))
            }
        }
    }

    /// Marks a message unread. Optimistically flips the local state, then reconciles from the
    /// server response. On failure the local flip is reverted so the UI reflects true state.
    func markUnread(_ messageID: Message.ID) async {
        guard let previousIsRead = messagesByID[messageID]?.isRead else { return }

        guard let identity = requireIdentity(context: "inbox mark-unread") else { return }

        if previousIsRead {
            messagesByID[messageID]?.isRead = false
            send(.loaded(orderedMessagesSnapshot()))
        }

        // Snapshot the refresh generation before the request. If an identity change
        // (`resetForIdentityChange`) or a newer `refreshUnreadCount` lands while the PATCH is in
        // flight, the generation advances and we drop this now-stale response instead of
        // restoring an old unread count.
        let generation = refreshGeneration

        do {
            let response = try await api.markMessagesUnread(
                pushToken: identity.pushToken,
                visitorId: identity.visitorId,
                messageIds: [messageID]
            )
            guard generation == refreshGeneration else { return }
            applyReadStatusResponse(response)
        } catch {
            Loggers.network.error("Failed to mark inbox message unread: \(error.localizedDescription, privacy: .public)")
            guard generation == refreshGeneration else { return }
            if messagesByID[messageID] != nil, previousIsRead {
                messagesByID[messageID]?.isRead = previousIsRead
                send(.loaded(orderedMessagesSnapshot()))
            }
        }
    }

    /// Deletes a message. Optimistically removes it locally, then issues the server delete.
    /// On failure the local removal is reverted (message re-inserted at its original index)
    /// so the UI reflects true state.
    func delete(_ messageID: Message.ID) async {
        guard let removedMessage = messagesByID[messageID],
              let originalIndex = messageOrder.firstIndex(of: messageID) else { return }

        let identity = identityProvider()
        guard !identity.visitorId.isEmpty else {
            Loggers.network.debug("Skipping inbox delete: empty visitor ID")
            return
        }

        messagesByID.removeValue(forKey: messageID)
        messageOrder.remove(at: originalIndex)
        send(.loaded(orderedMessagesSnapshot()))

        // Snapshot the *replaced* counter, not `messagesGeneration`, so the revert path drops
        // only when a successful refresh or identity reset actually replaced the local list —
        // a refresh that starts and fails during the DELETE preserves the current (already-
        // optimistically-removed) state, and we still need to revert.
        let replacedCountAtStart = messagesReplacedCount

        do {
            try await api.deleteInboxMessage(
                pushToken: identity.pushToken,
                visitorId: identity.visitorId,
                messageId: messageID
            )
        } catch {
            Loggers.network.error("Failed to delete inbox message: \(error.localizedDescription, privacy: .public)")
            guard replacedCountAtStart == messagesReplacedCount else { return }
            guard messagesByID[messageID] == nil else { return }
            messagesByID[messageID] = removedMessage
            let insertIndex = min(originalIndex, messageOrder.count)
            messageOrder.insert(messageID, at: insertIndex)
            send(.loaded(orderedMessagesSnapshot()))
        }
    }

    /// Reports a message tap. Delegates the read side to `markRead` (server POST + optimistic
    /// flip + count reconciliation + generation guarding) and separately fires the analytics-only
    /// click-tracking POST — the two endpoints have independent contracts and run concurrently.
    ///
    /// The click POST is fire-and-forget: errors are logged, never surfaced. It is skipped when
    /// the message has no `actionURL` because the server contract requires a non-blank
    /// `action_url` (returns 400 otherwise).
    func markClicked(_ messageID: Message.ID) async {
        guard let message = messagesByID[messageID] else { return }
        guard let identity = requireIdentity(context: "inbox click tracking") else { return }

        // Server rejects clicks without an action_url with a 400; skip rather than log a swallowed error.
        let actionURL = message.actionURLString?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        // Run mark-read and click POSTs concurrently — they hit different endpoints and neither
        // reads the other's response. Sequential await would double click-analytics tail latency.
        async let readTask: Void = markRead(messageID)
        async let clickTask: Void = performClickPost(
            identity: identity,
            messageId: messageID,
            actionURL: actionURL
        )
        _ = await (readTask, clickTask)
    }

    private func performClickPost(identity: InboxIdentitySnapshot, messageId: Message.ID, actionURL: String) async {
        guard !actionURL.isEmpty else {
            Loggers.network.debug("Skipping inbox click tracking: message has no actionURL")
            return
        }
        do {
            try await api.markMessageClicked(
                pushToken: identity.pushToken,
                visitorId: identity.visitorId,
                messageId: messageId,
                actionURL: actionURL
            )
        } catch {
            Loggers.network.error("Failed to report inbox click: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Clears all cached inbox state (messages, unread count, pagination cursor) and bumps both
    /// generations so any in-flight fetches from the previous identity are discarded when they
    /// return. Called on identity changes (`clearUser`, `updateUser`) so a logged-out account's
    /// messages and badge are not surfaced to the next user.
    func resetForIdentityChange() {
        refreshGeneration &+= 1
        messagesGeneration &+= 1
        messagesReplacedCount &+= 1
        storedUnreadCount = 0
        messagesByID = [:]
        messageOrder = []
        nextPageToken = nil
        hasFetchedFirstPage = false
        setLoadingNextPage(false)
        isRefreshingFirstPage = false
        // Only re-emit when we were already surfacing a loaded list — never override an
        // in-flight .loading state, which would strand hosts that don't re-present InboxView.
        if case .loaded = currentState {
            send(.loaded([]))
        }
    }
}

// MARK: - Private methods

extension InboxManager {
    /// Snapshots the current identity and returns it only when scoped requests are viable.
    /// Every inbox endpoint requires a non-empty `visitor_id`; returning nil (with a scoped log)
    /// keeps the six inbox network methods aligned on a single guard instead of six near-copies.
    private func requireIdentity(context: String) -> InboxIdentitySnapshot? {
        let identity = identityProvider()
        guard !identity.visitorId.isEmpty else {
            Loggers.network.debug("Skipping \(context, privacy: .public): empty visitor ID")
            return nil
        }
        return identity
    }

    private func removeContinuation(id: UUID) {
        continuations.removeValue(forKey: id)
    }

    private func removeLoadingMoreContinuation(id: UUID) {
        loadingMoreContinuations.removeValue(forKey: id)
    }

    private func send(_ state: InboxState) {
        currentState = state
        for continuation in continuations.values {
            continuation.yield(state)
        }
    }

    /// Single write path for `isLoadingNextPage` so every transition also fans out on
    /// `loadingMoreStream`. Skips the fan-out when the value hasn't actually changed.
    private func setLoadingNextPage(_ newValue: Bool) {
        guard isLoadingNextPage != newValue else { return }
        isLoadingNextPage = newValue
        for continuation in loadingMoreContinuations.values {
            continuation.yield(newValue)
        }
    }

    private func orderedMessagesSnapshot() -> [Message] {
        messageOrder.compactMap { messagesByID[$0] }
    }

    private func replaceMessages(with messages: [Message]) {
        messagesByID = [:]
        messageOrder = []
        messagesReplacedCount &+= 1
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

    /// Reconcile per-message read status and the authoritative unread count from a
    /// mark-read/mark-unread response.
    private func applyReadStatusResponse(_ response: UpdateReadStatusResponse) {
        for status in response.messages {
            messagesByID[status.messageId]?.isRead = status.isRead
        }
        storedUnreadCount = response.unreadCount
        send(.loaded(orderedMessagesSnapshot()))
    }
}
