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
    private var manager: InboxManager!
    private var viewModel: InboxViewModel!

    override func setUp() async throws {
        try await super.setUp()
        apiSpy = ATTNAPISpy(domain: "test-domain")
        manager = InboxManager(api: apiSpy) {
            InboxIdentitySnapshot(visitorId: "v_test", pushToken: "abc123", email: nil, phone: nil)
        }
        viewModel = InboxViewModel(inboxManager: manager, style: InboxStyle())
    }

    override func tearDown() async throws {
        apiSpy = nil
        manager = nil
        viewModel = nil
        try await super.tearDown()
    }

    // MARK: - Tap broadcasts

    func testClick_withActionURL_broadcastsNotificationWithURLAndId() async {
        let message = Message(
            id: "msg-1",
            title: "Title",
            body: "Body",
            timestamp: Date(),
            isRead: false,
            actionURLString: "myapp://products/sale"
        )

        let received = expectation(description: "notification received")
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
        XCTAssertEqual(capturedUserInfo?["attentiveInboxMessageId"] as? String, "msg-1")
        XCTAssertEqual(capturedUserInfo?["attentiveInboxActionUrl"] as? URL, URL(string: "myapp://products/sale"))
    }

    func testClick_withoutActionURL_stillBroadcastsWithId_omitsURL() async {
        let message = Message(
            id: "msg-2",
            title: "Title",
            body: "Body",
            timestamp: Date(),
            isRead: false,
            actionURLString: nil
        )

        let received = expectation(description: "notification received")
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
        XCTAssertEqual(capturedUserInfo?["attentiveInboxMessageId"] as? String, "msg-2")
        XCTAssertNil(capturedUserInfo?["attentiveInboxActionUrl"], "actionURL key must be absent when the message has no actionURL")
    }

    func testClick_withMalformedActionURL_omitsURLKey() async {
        // `Message.actionURL` returns nil for strings that don't parse to a URL; the notification
        // should not carry a bogus/empty entry.
        let message = Message(
            id: "msg-3",
            title: "Title",
            body: "Body",
            timestamp: Date(),
            isRead: false,
            actionURLString: ""
        )

        let received = expectation(description: "notification received")
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
        XCTAssertEqual(capturedUserInfo?["attentiveInboxMessageId"] as? String, "msg-3")
        XCTAssertNil(capturedUserInfo?["attentiveInboxActionUrl"])
    }
}
