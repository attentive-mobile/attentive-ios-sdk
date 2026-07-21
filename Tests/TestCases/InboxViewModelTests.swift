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

    func testClick_withActionURL_broadcastsIdAndURL() async {
        await assertClickBroadcast(
            id: "msg-1",
            actionURL: URL(string: "myapp://products/sale"),
            expectedURL: URL(string: "myapp://products/sale")
        )
    }

    func testClick_withNilActionURL_broadcastsIdOnly() async {
        await assertClickBroadcast(
            id: "msg-2",
            actionURL: nil,
            expectedURL: nil
        )
    }

    /// Drives `viewModel.click`, waits for the notification, and asserts userInfo shape:
    /// `attentiveInboxMessageId` is always present; `attentiveInboxActionUrl` is present iff
    /// `expectedURL` is non-nil.
    private func assertClickBroadcast(
        id: Message.ID,
        actionURL: URL?,
        expectedURL: URL?,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async {
        let received = expectation(description: "notification received for \(id)")
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

        viewModel.click(id: id, actionURL: actionURL)

        await fulfillment(of: [received], timeout: 1)
        XCTAssertEqual(capturedUserInfo?["attentiveInboxMessageId"] as? String, id, file: file, line: line)
        if let expectedURL {
            XCTAssertEqual(capturedUserInfo?["attentiveInboxActionUrl"] as? URL, expectedURL, file: file, line: line)
        } else {
            XCTAssertNil(
                capturedUserInfo?["attentiveInboxActionUrl"],
                "actionURL key must be absent when the caller passes nil",
                file: file, line: line
            )
        }
    }
}
