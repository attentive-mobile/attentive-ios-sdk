//
//  InboxViewModelTests.swift
//  attentive-ios-sdk Tests
//
//  Created by Adela Gao on 7/20/26.
//

import XCTest
@testable import ATTNSDKFramework

@MainActor
final class InboxViewModelTests: XCTestCase {
    private var apiSpy: ATTNAPISpy!
    private var urlOpenerSpy: ATTNURLOpenerSpy!
    private var manager: InboxManager!
    private var viewModel: InboxViewModel!

    override func setUp() async throws {
        try await super.setUp()
        apiSpy = ATTNAPISpy(domain: "test-domain")
        urlOpenerSpy = ATTNURLOpenerSpy()
        await makeSUT()
    }

    override func tearDown() async throws {
        apiSpy = nil
        urlOpenerSpy = nil
        manager = nil
        viewModel = nil
        try await super.tearDown()
    }

    // MARK: - Tap broadcasts

    func testClick_withActionURL_broadcastsIdAndURL() async {
        await assertClickBroadcast(
            message: makeMessage(id: "msg-1", actionURLString: "myapp://products/sale"),
            expectedURL: URL(string: "myapp://products/sale")
        )
    }

    func testClick_withNilActionURL_broadcastsIdOnly() async {
        await assertClickBroadcast(
            message: makeMessage(id: "msg-2"),
            expectedURL: nil
        )
    }

    // MARK: - Tap routing (default handler)

    func testClick_defaultHandler_opensActionURLAndTracksClick() async {
        let message = makeMessage(actionURLString: "https://example.com/sale")
        await makeSUT(seeding: message)

        viewModel.click(message)

        XCTAssertEqual(urlOpenerSpy.openedURLs, [URL(string: "https://example.com/sale")])
        // Plain open, no `.universalLinksOnly`: unclaimed http(s) links must fall back to the
        // browser (unlike push deep links, which never leave the app).
        XCTAssertTrue(urlOpenerSpy.lastOptions.isEmpty)
        await waitUntil("click tracking POST fires") { self.apiSpy.markMessageClickedWasCalled }
        XCTAssertEqual(apiSpy.lastMarkClickedMessageId, message.id)
    }

    func testClick_openReportsFailure_doesNotCrash() async {
        let message = makeMessage(actionURLString: "myapp://nobody-claims-this")
        await makeSUT(seeding: message)
        urlOpenerSpy.openResult = false

        viewModel.click(message)

        // Failure is logged and swallowed; tracking still fires.
        XCTAssertTrue(urlOpenerSpy.openWasCalled)
        await waitUntil("click tracking POST fires") { self.apiSpy.markMessageClickedWasCalled }
    }

    func testClick_autoOpenDisabled_doesNotOpenButStillTracksAndBroadcasts() async {
        // `automaticallyOpensInboxDeepLinks = false` suppresses only the SDK-initiated open;
        // click tracking and the ATTNSDKInboxMessageTapped broadcast still fire.
        let message = makeMessage(actionURLString: "https://example.com/sale")
        await makeSUT(seeding: message, shouldOpenDeepLink: { false })

        let notificationExpectation = expectation(forNotification: .ATTNSDKInboxMessageTapped, object: nil)

        viewModel.click(message)

        XCTAssertFalse(urlOpenerSpy.openWasCalled)
        await fulfillment(of: [notificationExpectation], timeout: 1.0)
        await waitUntil("click tracking POST fires") { self.apiSpy.markMessageClickedWasCalled }
    }

    func testClick_autoOpenDisabled_readAtTapTimeNotInitTime() async {
        // The flag must be consulted when the tap happens, so hosts can toggle
        // automaticallyOpensInboxDeepLinks after the inbox view is created.
        let message = makeMessage(actionURLString: "https://example.com/sale")
        var autoOpen = false
        await makeSUT(seeding: message, shouldOpenDeepLink: { autoOpen })

        viewModel.click(message)
        XCTAssertFalse(urlOpenerSpy.openWasCalled)

        autoOpen = true
        viewModel.click(message)
        XCTAssertEqual(urlOpenerSpy.openedURLs, [URL(string: "https://example.com/sale")])
    }

    func testClick_unsafeActionURLScheme_doesNotOpenButStillTracks() async {
        // Server-supplied action_url with a scriptable scheme must never reach
        // UIApplication.open; the broadcast + click tracking still run so hosts can decide.
        let message = makeMessage(actionURLString: "javascript:alert(1)")
        await makeSUT(seeding: message)

        viewModel.click(message)

        XCTAssertFalse(urlOpenerSpy.openWasCalled)
        await waitUntil("click tracking POST fires") { self.apiSpy.markMessageClickedWasCalled }
    }

    func testClick_withNilActionURL_doesNotOpenButStillTracks() async {
        let message = makeMessage()
        await makeSUT(seeding: message)

        viewModel.click(message)

        XCTAssertFalse(urlOpenerSpy.openWasCalled)
        // The click POST is skipped without an actionURL (server 400s on blank action_url),
        // but the tap still drives the read flip through markClicked.
        await waitUntil("mark-read POST fires") { self.apiSpy.markMessagesReadWasCalled }
        XCTAssertFalse(apiSpy.markMessageClickedWasCalled)
    }

    // MARK: - Tap routing (custom handler)

    func testClick_customOnTap_receivesMessageAndSkipsOpen() async {
        let message = makeMessage(actionURLString: "https://example.com/sale")
        var tappedMessages: [Message] = []
        await makeSUT(seeding: message, onTap: { tappedMessages.append($0) })

        viewModel.click(message)

        XCTAssertEqual(tappedMessages.map(\.id), [message.id])
        XCTAssertFalse(urlOpenerSpy.openWasCalled, "custom handler must replace the default open")
        // Click tracking is not overridable — it fires before the host handler runs.
        await waitUntil("click tracking POST fires") { self.apiSpy.markMessageClickedWasCalled }
    }

    func testClick_customOnTap_stillBroadcastsNotification() async {
        await makeSUT(onTap: { _ in })
        await assertClickBroadcast(
            message: makeMessage(id: "msg-3", actionURLString: "https://example.com"),
            expectedURL: URL(string: "https://example.com")
        )
    }

    func testClick_customOnTap_invokedEvenWithoutActionURL() async {
        let message = makeMessage()
        var tappedMessages: [Message] = []
        await makeSUT(seeding: message, onTap: { tappedMessages.append($0) })

        viewModel.click(message)

        XCTAssertEqual(tappedMessages.map(\.id), [message.id])
        XCTAssertFalse(urlOpenerSpy.openWasCalled)
    }

    // MARK: - Helpers

    /// Builds the manager + view model. `seeding` must be stubbed into the API spy *before*
    /// the manager exists: `InboxManager.init` fires its first-page fetch immediately, and
    /// `refresh()` coalesces with that init-time task, so a stub set afterwards is never read.
    private func makeSUT(
        seeding message: Message? = nil,
        onTap: ((Message) -> Void)? = nil,
        shouldOpenDeepLink: @escaping () -> Bool = { true }
    ) async {
        if let message {
            apiSpy.stubbedInboxMessagesResponses = [InboxResponse(messages: [message], nextPageToken: nil)]
        }
        manager = InboxManager(api: apiSpy) {
            InboxIdentitySnapshot(visitorId: "v_test", pushToken: "abc123", email: nil, phone: nil)
        }
        // Coalesces with the init-time fetch, guaranteeing the seeded page is cached on return.
        await manager.refresh()
        viewModel = InboxViewModel(
            inboxManager: manager,
            style: InboxStyle(),
            onTap: onTap,
            urlOpener: urlOpenerSpy,
            shouldOpenDeepLink: shouldOpenDeepLink
        )
    }

    private func makeMessage(id: Message.ID = "msg-1", actionURLString: String? = nil) -> Message {
        Message(
            id: id,
            title: "Title",
            body: "Body",
            timestamp: Date(timeIntervalSince1970: 1_700_000_000),
            isRead: false,
            actionURLString: actionURLString
        )
    }

    /// Polls until `condition` is true, failing the test at `timeout`. Used for effects the VM
    /// dispatches onto a detached Task (the markClicked call) rather than running inline.
    private func waitUntil(
        _ label: String,
        timeout: TimeInterval = 1,
        file: StaticString = #filePath,
        line: UInt = #line,
        _ condition: @escaping () -> Bool
    ) async {
        let deadline = Date().addingTimeInterval(timeout)
        while !condition() {
            guard Date() < deadline else {
                XCTFail("Timed out waiting for: \(label)", file: file, line: line)
                return
            }
            try? await Task.sleep(nanoseconds: 10_000_000)
        }
    }

    /// Drives `viewModel.click`, waits for the notification, and asserts userInfo shape:
    /// `attentiveInboxMessageId` is always present; `attentiveInboxActionUrl` is present iff
    /// `expectedURL` is non-nil.
    private func assertClickBroadcast(
        message: Message,
        expectedURL: URL?,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async {
        let received = expectation(description: "notification received for \(message.id)")
        var capturedUserInfo: [AnyHashable: Any]?
        let observer = NotificationCenter.default.addObserver(
            forName: .ATTNSDKInboxMessageTapped,
            object: nil,
            queue: .main
        ) { notification in
            capturedUserInfo = notification.userInfo
            received.fulfill()
        }
        defer { NotificationCenter.default.removeObserver(observer) }

        viewModel.click(message)

        await fulfillment(of: [received], timeout: 1)
        XCTAssertEqual(capturedUserInfo?["attentiveInboxMessageId"] as? String, message.id, file: file, line: line)
        if let expectedURL {
            XCTAssertEqual(capturedUserInfo?["attentiveInboxActionUrl"] as? URL, expectedURL, file: file, line: line)
        } else {
            XCTAssertNil(
                capturedUserInfo?["attentiveInboxActionUrl"],
                "actionURL key must be absent when the message has no actionURL",
                file: file, line: line
            )
        }
    }
}
