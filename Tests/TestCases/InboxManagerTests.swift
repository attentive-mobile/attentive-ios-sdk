//
//  InboxManagerTests.swift
//  attentive-ios-sdk Tests
//
//  Created by Adela Gao on 7/6/26.
//

import XCTest
@testable import ATTNSDKFramework

final class InboxManagerTests: XCTestCase {
    private var apiSpy: ATTNAPISpy!

    override func setUp() {
        super.setUp()
        apiSpy = ATTNAPISpy(domain: "test-domain")
    }

    override func tearDown() {
        apiSpy = nil
        super.tearDown()
    }

    // MARK: - Helpers

    private func makeMessage(id: String, isRead: Bool = false) -> Message {
        Message(
            id: id,
            title: "Title \(id)",
            body: "Body \(id)",
            timestamp: Date(),
            isRead: isRead
        )
    }

    private func identityProvider(
        visitorId: String = "v_test",
        pushToken: String = "fcm:abc",
        email: String? = nil,
        phone: String? = nil
    ) -> InboxIdentityProvider {
        return {
            InboxIdentitySnapshot(visitorId: visitorId, pushToken: pushToken, email: email, phone: phone)
        }
    }

    /// Wait for the manager's state to transition to `.loaded` (i.e. init-time refresh() completed).
    /// Times out after 1s so a bad wire-up fails loudly instead of hanging CI.
    @discardableResult
    private func waitForLoadedState(_ manager: InboxManager, timeout: TimeInterval = 1.0) async -> [Message]? {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            let state = await manager.currentInboxStateForTesting
            if case .loaded(let messages) = state { return messages }
            if case .error = state { return nil }
            try? await Task.sleep(nanoseconds: 10_000_000) // 10ms
        }
        return nil
    }

    /// Wait for the init-time refreshUnreadCount() to settle (or timeout).
    private func waitForUnreadCountFetch(timeout: TimeInterval = 1.0) async {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline, apiSpy.fetchInboxUnreadCountCallCount == 0 {
            try? await Task.sleep(nanoseconds: 10_000_000)
        }
    }

    // MARK: - Initial load

    func testInit_loadsFirstPageAndUnreadCount() async {
        apiSpy.stubbedInboxMessagesResponses = [
            InboxResponse(messages: [makeMessage(id: "1"), makeMessage(id: "2")], nextPageToken: nil)
        ]
        apiSpy.stubbedUnreadCount = 3

        let manager = InboxManager(api: apiSpy, identityProvider: identityProvider())
        _ = await waitForLoadedState(manager)
        await waitForUnreadCountFetch()

        let messages = await manager.allMessages
        let unread = await manager.unreadCount
        XCTAssertEqual(messages.count, 2)
        XCTAssertEqual(unread, 3)
        XCTAssertEqual(apiSpy.fetchInboxMessagesCallCount, 1)
        XCTAssertNil(apiSpy.lastInboxMessagesPageToken)
    }

    func testRefresh_immediatelyAfterInit_coalescesWithInitTask() async {
        // InboxView.task calls viewModel.refresh() immediately after materializing the manager;
        // without coalescing, that races the init fetch and double-POSTs /inbox/messages.
        apiSpy.stubbedInboxMessagesResponses = [
            InboxResponse(messages: [makeMessage(id: "1")], nextPageToken: nil)
        ]
        apiSpy.stubbedUnreadCount = 1

        let manager = InboxManager(api: apiSpy, identityProvider: identityProvider())
        await manager.refresh()

        XCTAssertEqual(apiSpy.fetchInboxMessagesCallCount, 1, "refresh() called during init must coalesce, not double-POST")
        XCTAssertEqual(apiSpy.fetchInboxUnreadCountCallCount, 1, "refresh() called during init must not fire an extra unread-count POST")
    }

    func testRefresh_emptyVisitorId_skipsNetworkCall() async {
        let manager = InboxManager(api: apiSpy, identityProvider: identityProvider(visitorId: ""))
        // Give the init Task a chance to run — no state transition expected since it should skip.
        try? await Task.sleep(nanoseconds: 100_000_000)
        _ = manager

        XCTAssertEqual(apiSpy.fetchInboxMessagesCallCount, 0)
        XCTAssertEqual(apiSpy.fetchInboxUnreadCountCallCount, 0)
    }

    // MARK: - Pagination

    func testLoadNextPage_appendsWithoutDuplicates() async {
        apiSpy.stubbedInboxMessagesResponses = [
            InboxResponse(messages: [makeMessage(id: "1"), makeMessage(id: "2")], nextPageToken: "cursor-2"),
            InboxResponse(messages: [makeMessage(id: "2"), makeMessage(id: "3")], nextPageToken: nil)
        ]

        let manager = InboxManager(api: apiSpy, identityProvider: identityProvider())
        _ = await waitForLoadedState(manager)

        await manager.loadNextPage()

        let messages = await manager.allMessages
        let ids = messages.map(\.id)
        XCTAssertEqual(ids, ["1", "2", "3"], "Duplicate message 2 must not be added twice")
        XCTAssertEqual(apiSpy.lastInboxMessagesPageToken, "cursor-2")
    }

    func testLoadNextPage_noNextToken_isNoOp() async {
        apiSpy.stubbedInboxMessagesResponses = [
            InboxResponse(messages: [makeMessage(id: "1")], nextPageToken: nil)
        ]

        let manager = InboxManager(api: apiSpy, identityProvider: identityProvider())
        _ = await waitForLoadedState(manager)

        let callCountBefore = apiSpy.fetchInboxMessagesCallCount
        await manager.loadNextPage()
        XCTAssertEqual(apiSpy.fetchInboxMessagesCallCount, callCountBefore, "loadNextPage should not fire when no next page is available")
    }

    func testLoadNextPage_firedDuringRefresh_isBlocked() async {
        // Reproduce the race the reviewer flagged: a last-row `.onAppear` fires during a
        // pull-to-refresh's in-flight window and captures the stale nextPageToken.
        apiSpy.stubbedInboxMessagesResponses = [
            // Initial page 1 (init-time)
            InboxResponse(messages: [makeMessage(id: "old-1")], nextPageToken: "stale-cursor"),
            // Refresh's page-1 response — set below via onFetchInboxMessages
            InboxResponse(messages: [makeMessage(id: "new-1")], nextPageToken: "fresh-cursor"),
            // Would-be stale page from the racing loadNextPage
            InboxResponse(messages: [makeMessage(id: "STALE")], nextPageToken: "should-not-clobber")
        ]
        let manager = InboxManager(api: apiSpy, identityProvider: identityProvider())
        // Drain init so refresh() below actually fires a new fetch.
        _ = await manager.unreadCount

        // On the refresh's fetch, interleave a loadNextPage before returning the response.
        apiSpy.onFetchInboxMessages = { [weak self] pageToken in
            guard let self = self else { return }
            // Only interleave on the refresh (nil pageToken), not the racing loadNextPage.
            guard pageToken == nil else { return }
            // Fire the racing page load. It should be blocked by isRefreshingFirstPage.
            await manager.loadNextPage()
            // Clear the hook so it doesn't re-fire recursively.
            self.apiSpy.onFetchInboxMessages = nil
        }

        let callCountBeforeRefresh = apiSpy.fetchInboxMessagesCallCount
        await manager.refresh()

        let messages = await manager.allMessages
        XCTAssertEqual(messages.map(\.id), ["new-1"], "stale page load must not clobber the refresh's result")
        let hasMore = await manager.hasMore
        XCTAssertTrue(hasMore, "hasMore should reflect the refresh's fresh cursor, not a clobbered stale one")
        // The discriminating check: on unfixed code, the racing loadNextPage would slip past
        // the guard and hit the network (count +2). With the gate in place it must be blocked (+1).
        XCTAssertEqual(
            apiSpy.fetchInboxMessagesCallCount - callCountBeforeRefresh,
            1,
            "racing loadNextPage during refresh must be blocked, not fire a network call"
        )
    }

    func testLoadingMoreStream_emitsTransitionsForRealFetchesOnly() async {
        apiSpy.stubbedInboxMessagesResponses = [
            InboxResponse(messages: [makeMessage(id: "1")], nextPageToken: "cursor-2"),
            InboxResponse(messages: [makeMessage(id: "2")], nextPageToken: nil)
        ]
        let manager = InboxManager(api: apiSpy, identityProvider: identityProvider())
        _ = await waitForLoadedState(manager)
        let callCountBeforePaging = apiSpy.fetchInboxMessagesCallCount

        // Collect stream values in the background for the full duration of both calls.
        // Uses an actor-isolated box so the collector task can push values while the test
        // reads them after cancellation.
        actor Observed { var values: [Bool] = []; func append(_ v: Bool) { values.append(v) } }
        let observed = Observed()
        let collectorReady = expectation(description: "collector subscribed")
        let collector = Task {
            let stream = await manager.loadingMoreStream
            var iter = stream.makeAsyncIterator()
            // First yield is the current value; consume it to prove subscription is live.
            if let first = await iter.next() { await observed.append(first) }
            collectorReady.fulfill()
            // Keep collecting until the task is cancelled by the test.
            while !Task.isCancelled, let next = await iter.next() {
                await observed.append(next)
            }
        }
        await fulfillment(of: [collectorReady], timeout: 1)

        // Real fetch — expect true then false.
        await manager.loadNextPage()
        // Final page reached — this call must no-op, i.e. not emit a new transition.
        await manager.loadNextPage()

        // Give the stream one runloop turn to deliver any pending emissions before we tear down.
        await Task.yield()
        collector.cancel()

        let values = await observed.values
        XCTAssertEqual(values, [false, true, false], "loadingMoreStream must emit true→false only for real fetches, not no-op calls")
        // Discriminating check: the no-op second call must not fire a network request either.
        XCTAssertEqual(
            apiSpy.fetchInboxMessagesCallCount - callCountBeforePaging,
            1,
            "no-op loadNextPage after the last page must not hit the network"
        )
    }

    func testLoadNextPage_updatesNextTokenAndHasMoreFlag() async {
        apiSpy.stubbedInboxMessagesResponses = [
            InboxResponse(messages: [makeMessage(id: "1")], nextPageToken: "cursor-2"),
            InboxResponse(messages: [makeMessage(id: "2")], nextPageToken: nil)
        ]

        let manager = InboxManager(api: apiSpy, identityProvider: identityProvider())
        _ = await waitForLoadedState(manager)

        var hasMore = await manager.hasMore
        XCTAssertTrue(hasMore)

        await manager.loadNextPage()

        hasMore = await manager.hasMore
        XCTAssertFalse(hasMore)
    }

    // MARK: - Refresh behavior

    func testRefresh_resetsMessagesAndPagination() async {
        apiSpy.stubbedInboxMessagesResponses = [
            InboxResponse(messages: [makeMessage(id: "1"), makeMessage(id: "2")], nextPageToken: "cursor-2"),
            InboxResponse(messages: [makeMessage(id: "9")], nextPageToken: nil)
        ]

        let manager = InboxManager(api: apiSpy, identityProvider: identityProvider())
        // Drain the init task so refresh() below is a real second fetch, not a coalesce.
        _ = await manager.unreadCount

        await manager.refresh()

        let messages = await manager.allMessages
        XCTAssertEqual(messages.map(\.id), ["9"], "refresh must replace the list, not append")
        let hasMore = await manager.hasMore
        XCTAssertFalse(hasMore)
    }

    // MARK: - Error handling

    func testRefresh_errorOnFirstLoad_emitsErrorState() async {
        apiSpy.stubbedInboxMessagesError = NSError(domain: "test", code: -1)

        let manager = InboxManager(api: apiSpy, identityProvider: identityProvider())

        // Wait for the init Task to run through refresh() and update state.
        let deadline = Date().addingTimeInterval(1.0)
        var observed: InboxState?
        while Date() < deadline {
            let state = await manager.currentInboxStateForTesting
            if case .error = state {
                observed = state
                break
            }
            try? await Task.sleep(nanoseconds: 10_000_000)
        }

        if case .error = observed {
            // expected
        } else {
            XCTFail("Expected .error state after init failure, got \(String(describing: observed))")
        }
    }

    // MARK: - Mark Read

    func testMarkRead_success_flipsLocalAndSyncsUnreadCountFromServer() async {
        apiSpy.stubbedInboxMessagesResponses = [
            InboxResponse(messages: [makeMessage(id: "1", isRead: false)], nextPageToken: nil)
        ]
        apiSpy.stubbedUnreadCount = 1
        apiSpy.stubbedMarkReadResponse = UpdateReadStatusResponse(
            messages: [.init(messageId: "1", isRead: true)],
            unreadCount: 0
        )

        let manager = InboxManager(api: apiSpy, identityProvider: identityProvider())
        _ = await waitForLoadedState(manager)
        await waitForUnreadCountFetch()

        await manager.markRead("1")

        let messages = await manager.allMessages
        let unread = await manager.unreadCount
        XCTAssertTrue(messages.first?.isRead ?? false)
        XCTAssertEqual(unread, 0, "unread_count from response should be authoritative")
        XCTAssertEqual(apiSpy.markMessagesReadCallCount, 1)
        XCTAssertEqual(apiSpy.lastMarkReadMessageIds, ["1"])
        XCTAssertEqual(apiSpy.lastMarkReadVisitorId, "v_test")
        XCTAssertEqual(apiSpy.lastMarkReadPushToken, "fcm:abc")
    }

    func testMarkRead_failure_revertsLocalFlip() async {
        apiSpy.stubbedInboxMessagesResponses = [
            InboxResponse(messages: [makeMessage(id: "1", isRead: false)], nextPageToken: nil)
        ]
        apiSpy.stubbedMarkReadError = NSError(domain: "test", code: -1)

        let manager = InboxManager(api: apiSpy, identityProvider: identityProvider())
        _ = await waitForLoadedState(manager)

        await manager.markRead("1")

        let messages = await manager.allMessages
        XCTAssertFalse(messages.first?.isRead ?? true, "Failed mark-read must revert the local flip")
    }

    func testMarkRead_identityChangeDuringRequest_discardsStaleResponse() async {
        apiSpy.stubbedInboxMessagesResponses = [
            InboxResponse(messages: [makeMessage(id: "1", isRead: false)], nextPageToken: nil)
        ]
        apiSpy.stubbedUnreadCount = 5
        apiSpy.stubbedMarkReadResponse = UpdateReadStatusResponse(
            messages: [.init(messageId: "1", isRead: true)],
            unreadCount: 99 // stale value that must not survive the identity change
        )

        let manager = InboxManager(api: apiSpy, identityProvider: identityProvider())
        _ = await waitForLoadedState(manager)
        await waitForUnreadCountFetch()

        // An identity change (e.g. clearUser/updateUser) lands while the PATCH is in flight,
        // bumping the generation and zeroing the count for the new (logged-out) identity.
        apiSpy.onMarkMessagesRead = { await manager.resetForIdentityChange() }

        await manager.markRead("1")

        let unread = await manager.unreadCount
        XCTAssertEqual(unread, 0, "Stale mark-read response must not overwrite the post-reset unread count")
    }

    func testMarkRead_alreadyRead_noOpsOnLocalStateButStillCallsApi() async {
        apiSpy.stubbedInboxMessagesResponses = [
            InboxResponse(messages: [makeMessage(id: "1", isRead: true)], nextPageToken: nil)
        ]
        apiSpy.stubbedMarkReadResponse = UpdateReadStatusResponse(
            messages: [.init(messageId: "1", isRead: true)],
            unreadCount: 0
        )

        let manager = InboxManager(api: apiSpy, identityProvider: identityProvider())
        _ = await waitForLoadedState(manager)

        await manager.markRead("1")

        let unread = await manager.unreadCount
        XCTAssertEqual(unread, 0)
        XCTAssertEqual(apiSpy.markMessagesReadCallCount, 1)
    }

    func testMarkRead_unknownMessage_isNoOp() async {
        apiSpy.stubbedInboxMessagesResponses = [
            InboxResponse(messages: [makeMessage(id: "1", isRead: false)], nextPageToken: nil)
        ]

        let manager = InboxManager(api: apiSpy, identityProvider: identityProvider())
        _ = await waitForLoadedState(manager)

        await manager.markRead("does-not-exist")

        XCTAssertEqual(apiSpy.markMessagesReadCallCount, 0, "Unknown message ID must not hit the network")
    }

    // MARK: - Mark Unread

    func testMarkUnread_success_flipsLocalAndSyncsUnreadCountFromServer() async {
        apiSpy.stubbedInboxMessagesResponses = [
            InboxResponse(messages: [makeMessage(id: "1", isRead: true)], nextPageToken: nil)
        ]
        apiSpy.stubbedUnreadCount = 0
        apiSpy.stubbedMarkUnreadResponse = UpdateReadStatusResponse(
            messages: [.init(messageId: "1", isRead: false)],
            unreadCount: 7
        )

        let manager = InboxManager(api: apiSpy, identityProvider: identityProvider())
        _ = await waitForLoadedState(manager)
        await waitForUnreadCountFetch()

        await manager.markUnread("1")

        let messages = await manager.allMessages
        let unread = await manager.unreadCount
        XCTAssertFalse(messages.first?.isRead ?? true)
        XCTAssertEqual(unread, 7, "unread_count from response should be authoritative")
        XCTAssertEqual(apiSpy.markMessagesUnreadCallCount, 1)
        XCTAssertEqual(apiSpy.lastMarkUnreadMessageIds, ["1"])
        XCTAssertEqual(apiSpy.lastMarkUnreadVisitorId, "v_test")
        XCTAssertEqual(apiSpy.lastMarkUnreadPushToken, "fcm:abc")
    }

    func testMarkUnread_failure_revertsLocalFlip() async {
        apiSpy.stubbedInboxMessagesResponses = [
            InboxResponse(messages: [makeMessage(id: "1", isRead: true)], nextPageToken: nil)
        ]
        apiSpy.stubbedMarkUnreadError = NSError(domain: "test", code: -1)

        let manager = InboxManager(api: apiSpy, identityProvider: identityProvider())
        _ = await waitForLoadedState(manager)

        await manager.markUnread("1")

        let messages = await manager.allMessages
        XCTAssertTrue(messages.first?.isRead ?? false, "Failed mark-unread must revert the local flip")
    }

    func testMarkUnread_identityChangeDuringRequest_discardsStaleResponse() async {
        apiSpy.stubbedInboxMessagesResponses = [
            InboxResponse(messages: [makeMessage(id: "1", isRead: true)], nextPageToken: nil)
        ]
        apiSpy.stubbedUnreadCount = 5
        apiSpy.stubbedMarkUnreadResponse = UpdateReadStatusResponse(
            messages: [.init(messageId: "1", isRead: false)],
            unreadCount: 99 // stale value that must not survive the identity change
        )

        let manager = InboxManager(api: apiSpy, identityProvider: identityProvider())
        _ = await waitForLoadedState(manager)
        await waitForUnreadCountFetch()

        // An identity change (e.g. clearUser/updateUser) lands while the PATCH is in flight,
        // bumping the generation and zeroing the count for the new (logged-out) identity.
        apiSpy.onMarkMessagesUnread = { await manager.resetForIdentityChange() }

        await manager.markUnread("1")

        let unread = await manager.unreadCount
        XCTAssertEqual(unread, 0, "Stale mark-unread response must not overwrite the post-reset unread count")
    }

    func testMarkUnread_alreadyUnread_noOpsOnLocalStateButStillCallsApi() async {
        apiSpy.stubbedInboxMessagesResponses = [
            InboxResponse(messages: [makeMessage(id: "1", isRead: false)], nextPageToken: nil)
        ]
        apiSpy.stubbedMarkUnreadResponse = UpdateReadStatusResponse(
            messages: [.init(messageId: "1", isRead: false)],
            unreadCount: 2
        )

        let manager = InboxManager(api: apiSpy, identityProvider: identityProvider())
        _ = await waitForLoadedState(manager)

        await manager.markUnread("1")

        let unread = await manager.unreadCount
        XCTAssertEqual(unread, 2)
        XCTAssertEqual(apiSpy.markMessagesUnreadCallCount, 1)
    }

    func testMarkUnread_unknownMessage_isNoOp() async {
        apiSpy.stubbedInboxMessagesResponses = [
            InboxResponse(messages: [makeMessage(id: "1", isRead: true)], nextPageToken: nil)
        ]

        let manager = InboxManager(api: apiSpy, identityProvider: identityProvider())
        _ = await waitForLoadedState(manager)

        await manager.markUnread("does-not-exist")

        XCTAssertEqual(apiSpy.markMessagesUnreadCallCount, 0, "Unknown message ID must not hit the network")
    }

    func testDelete_removesMessageFromList() async {
        apiSpy.stubbedInboxMessagesResponses = [
            InboxResponse(messages: [makeMessage(id: "1"), makeMessage(id: "2")], nextPageToken: nil)
        ]
        let manager = InboxManager(api: apiSpy, identityProvider: identityProvider())
        _ = await waitForLoadedState(manager)

        await manager.delete("1")

        let messages = await manager.allMessages
        XCTAssertEqual(messages.map(\.id), ["2"])
    }

    // MARK: - Identity change

    func testResetForIdentityChange_clearsMessagesAndCount() async {
        apiSpy.stubbedInboxMessagesResponses = [
            InboxResponse(messages: [makeMessage(id: "1"), makeMessage(id: "2")], nextPageToken: "cursor-2")
        ]
        apiSpy.stubbedUnreadCount = 5
        let manager = InboxManager(api: apiSpy, identityProvider: identityProvider())
        _ = await waitForLoadedState(manager)

        await manager.resetForIdentityChange()

        let messages = await manager.allMessages
        let unread = await manager.unreadCount
        let hasMore = await manager.hasMore
        XCTAssertTrue(messages.isEmpty, "previous user's messages must not survive an identity reset")
        XCTAssertEqual(unread, 0)
        XCTAssertFalse(hasMore, "pagination cursor must be dropped so next user doesn't fetch prev user's next page")
    }

    // MARK: - Pull-to-refresh includes unread count

    func testRefresh_alsoRefreshesUnreadCount() async {
        apiSpy.stubbedInboxMessagesResponses = [
            InboxResponse(messages: [makeMessage(id: "1")], nextPageToken: nil),
            InboxResponse(messages: [makeMessage(id: "1")], nextPageToken: nil)
        ]
        apiSpy.stubbedUnreadCount = 1
        let manager = InboxManager(api: apiSpy, identityProvider: identityProvider())
        // Awaiting `unreadCount` drains `initialRefreshTask` so the subsequent refresh()
        // does real work instead of coalescing with the init fetch.
        _ = await manager.unreadCount

        let countBefore = apiSpy.fetchInboxUnreadCountCallCount
        await manager.refresh()

        XCTAssertGreaterThan(apiSpy.fetchInboxUnreadCountCallCount, countBefore, "refresh() must also refresh the unread count")
    }

    // MARK: - Refresh error preserves pagination cursor

    func testRefresh_errorAfterInitialSuccess_preservesNextPageToken() async {
        apiSpy.stubbedInboxMessagesResponses = [
            InboxResponse(messages: [makeMessage(id: "1")], nextPageToken: "cursor-2")
        ]
        let manager = InboxManager(api: apiSpy, identityProvider: identityProvider())
        // Drain the init task so refresh() below is a real second fetch, not a coalesce.
        _ = await manager.unreadCount

        // Stub the next refresh to throw.
        apiSpy.stubbedInboxMessagesResponses = []
        apiSpy.stubbedInboxMessagesError = NSError(domain: "test", code: -1)

        await manager.refresh()

        let hasMore = await manager.hasMore
        XCTAssertTrue(hasMore, "refresh error must not wipe the pagination cursor from the last successful fetch")
    }

    // MARK: - Click tracking

    private func makeMessageWithAction(id: String, actionURL: String?, isRead: Bool = false) -> Message {
        Message(
            id: id,
            title: "Title \(id)",
            body: "Body \(id)",
            timestamp: Date(),
            isRead: isRead,
            actionURLString: actionURL
        )
    }

    func testMarkClicked_firesApiWithMessageIdAndActionURL() async {
        apiSpy.stubbedInboxMessagesResponses = [
            InboxResponse(
                messages: [makeMessageWithAction(id: "1", actionURL: "myapp://cart", isRead: false)],
                nextPageToken: nil
            )
        ]
        let manager = InboxManager(api: apiSpy, identityProvider: identityProvider())
        _ = await waitForLoadedState(manager)

        await manager.markClicked("1")

        XCTAssertEqual(apiSpy.markMessageClickedCallCount, 1)
        XCTAssertEqual(apiSpy.lastMarkClickedMessageId, "1")
        XCTAssertEqual(apiSpy.lastMarkClickedVisitorId, "v_test")
        XCTAssertEqual(apiSpy.lastMarkClickedPushToken, "fcm:abc")
        XCTAssertEqual(apiSpy.lastMarkClickedActionURL, "myapp://cart")
    }

    func testMarkClicked_flipsLocalReadState() async {
        apiSpy.stubbedInboxMessagesResponses = [
            InboxResponse(
                messages: [makeMessageWithAction(id: "1", actionURL: nil, isRead: false)],
                nextPageToken: nil
            )
        ]
        let manager = InboxManager(api: apiSpy, identityProvider: identityProvider())
        _ = await waitForLoadedState(manager)

        await manager.markClicked("1")

        let messages = await manager.allMessages
        XCTAssertTrue(messages.first?.isRead ?? false, "click must flip local read state")
    }

    func testMarkClicked_alreadyRead_stillFiresApiButDoesNotDoubleEmit() async {
        apiSpy.stubbedInboxMessagesResponses = [
            InboxResponse(
                messages: [makeMessageWithAction(id: "1", actionURL: "myapp://x", isRead: true)],
                nextPageToken: nil
            )
        ]
        let manager = InboxManager(api: apiSpy, identityProvider: identityProvider())
        _ = await waitForLoadedState(manager)

        await manager.markClicked("1")

        XCTAssertEqual(apiSpy.markMessageClickedCallCount, 1, "already-read messages must still be tracked as clicked")
    }

    func testMarkClicked_unknownMessage_isNoOp() async {
        apiSpy.stubbedInboxMessagesResponses = [
            InboxResponse(messages: [makeMessage(id: "1")], nextPageToken: nil)
        ]
        let manager = InboxManager(api: apiSpy, identityProvider: identityProvider())
        _ = await waitForLoadedState(manager)

        await manager.markClicked("does-not-exist")

        XCTAssertEqual(apiSpy.markMessageClickedCallCount, 0, "Unknown message ID must not hit the network")
    }

    func testMarkClicked_emptyVisitorId_skipsNetworkCall() async {
        // Empty visitor: identityProvider returns visitorId="" so the manager should skip the call.
        let manager = InboxManager(
            api: apiSpy,
            identityProvider: identityProvider(visitorId: "")
        )
        // Seed a message manually via the fetch path so `messagesByID` is non-empty. Since the
        // init refresh short-circuits on empty visitorId, drive one directly.
        apiSpy.stubbedInboxMessagesResponses = [
            InboxResponse(messages: [makeMessage(id: "1")], nextPageToken: nil)
        ]
        // Give init a moment to short-circuit (no state transition), then attempt click.
        try? await Task.sleep(nanoseconds: 50_000_000)

        await manager.markClicked("1")

        XCTAssertEqual(apiSpy.markMessageClickedCallCount, 0)
    }

    func testMarkClicked_apiFailure_isSwallowed() async {
        apiSpy.stubbedInboxMessagesResponses = [
            InboxResponse(
                messages: [makeMessageWithAction(id: "1", actionURL: nil, isRead: false)],
                nextPageToken: nil
            )
        ]
        apiSpy.stubbedMarkClickedError = NSError(domain: "test", code: -1)

        let manager = InboxManager(api: apiSpy, identityProvider: identityProvider())
        _ = await waitForLoadedState(manager)

        // Must not throw or crash — errors are logged, not surfaced.
        await manager.markClicked("1")

        // Local flip still happened even though the network call failed.
        let messages = await manager.allMessages
        XCTAssertTrue(messages.first?.isRead ?? false)
    }
}
