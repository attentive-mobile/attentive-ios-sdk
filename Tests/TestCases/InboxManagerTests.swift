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

        await manager.refresh()

        let messages = await manager.allMessages
        XCTAssertEqual(messages.map(\.id), ["new-1"], "stale page load must not clobber the refresh's result")
        let hasMore = await manager.hasMore
        XCTAssertTrue(hasMore, "hasMore should reflect the refresh's fresh cursor, not a clobbered stale one")
    }

    func testLoadingMoreStream_emitsTransitionsForRealFetchesOnly() async {
        apiSpy.stubbedInboxMessagesResponses = [
            InboxResponse(messages: [makeMessage(id: "1")], nextPageToken: "cursor-2"),
            InboxResponse(messages: [makeMessage(id: "2")], nextPageToken: nil)
        ]
        let manager = InboxManager(api: apiSpy, identityProvider: identityProvider())
        _ = await waitForLoadedState(manager)

        // Collect stream values in the background so we can observe transitions.
        var observed: [Bool] = []
        let collectorReady = expectation(description: "collector subscribed")
        let collector = Task {
            let stream = await manager.loadingMoreStream
            var iter = stream.makeAsyncIterator()
            // First yield is the current value; consume it to prove subscription is live.
            if let first = await iter.next() { observed.append(first) }
            collectorReady.fulfill()
            while let next = await iter.next() {
                observed.append(next)
                if !next && observed.count >= 3 { break } // saw true then false, done
            }
        }
        await fulfillment(of: [collectorReady], timeout: 1)

        // Real fetch — expect true then false.
        await manager.loadNextPage()
        // Final page reached — this call must no-op, i.e. not emit a new transition.
        await manager.loadNextPage()

        _ = await collector.value
        XCTAssertEqual(observed, [false, true, false], "loadingMoreStream must emit true→false only for real fetches, not no-op calls")
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

    // MARK: - Local mutations

    func testMarkRead_updatesLocalMessageState() async {
        apiSpy.stubbedInboxMessagesResponses = [
            InboxResponse(messages: [makeMessage(id: "1", isRead: false)], nextPageToken: nil)
        ]
        let manager = InboxManager(api: apiSpy, identityProvider: identityProvider())
        _ = await waitForLoadedState(manager)

        await manager.markRead("1")

        let messages = await manager.allMessages
        XCTAssertTrue(messages.first?.isRead == true)
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
}
