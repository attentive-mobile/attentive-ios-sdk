//
//  ATTNInboxClickAPITests.swift
//  attentive-ios-sdk Tests
//
//  Created by Adela Gao on 7/20/26.
//

import XCTest
@testable import ATTNSDKFramework

final class ATTNInboxClickAPITests: XCTestCase {
    private let testDomain = "some-domain"
    private var sessionMock: NSURLSessionMock!
    private var api: ATTNAPI!
    private var userIdentity: ATTNUserIdentity!

    override func setUp() {
        super.setUp()
        sessionMock = NSURLSessionMock()
        api = ATTNAPI(domain: testDomain, urlSession: sessionMock)
        userIdentity = ATTNTestEventUtils.buildUserIdentity()
    }

    override func tearDown() {
        sessionMock = nil
        api = nil
        userIdentity = nil
        super.tearDown()
    }

    private func markClicked(
        pushToken: String = "abc123devicetoken",
        messageId: String = "msg_abc123",
        actionURL: String? = "myapp://products/sale",
        identity: ATTNUserIdentity? = nil
    ) async throws {
        try await api.markMessageClicked(
            pushToken: pushToken,
            visitorId: (identity ?? userIdentity).visitorId,
            messageId: messageId,
            actionURL: actionURL
        )
    }

    // MARK: - Success

    func testMarkClicked_success_204() async throws {
        // Default sessionMock returns 204 No Content.
        try await markClicked()

        XCTAssertTrue(sessionMock.didCallInboxClickedApi)
        XCTAssertEqual(sessionMock.urlCalls.count, 1)
        XCTAssertEqual(sessionMock.urlCalls[0].absoluteString, "https://mobile.attentivemobile.com/inbox/events/clicked")
    }

    func testMarkClicked_sendsExpectedRequest() async throws {
        try await markClicked(messageId: "msg-xyz", actionURL: "myapp://cart")

        let request = try XCTUnwrap(sessionMock.requests.first)
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")

        let body = try XCTUnwrap(request.httpBody)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])

        XCTAssertEqual(json["c"] as? String, testDomain)
        XCTAssertEqual(json["visitor_id"] as? String, userIdentity.visitorId)
        // Push tokens are namespaced by transport for the inbox backend.
        XCTAssertEqual(json["push_token"] as? String, "apns:abc123devicetoken")
        XCTAssertEqual(json["message_id"] as? String, "msg-xyz")
        XCTAssertEqual(json["action_url"] as? String, "myapp://cart")
        // Click contract does not carry email/phone (server scopes by identity).
        XCTAssertNil(json["email"])
        XCTAssertNil(json["phone"])
    }

    func testMarkClicked_omitsEmptyPushToken() async throws {
        try await markClicked(pushToken: "")

        let request = try XCTUnwrap(sessionMock.requests.first)
        let body = try XCTUnwrap(request.httpBody)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])

        XCTAssertNil(json["push_token"])
        XCTAssertEqual(json["visitor_id"] as? String, userIdentity.visitorId)
    }

    func testMarkClicked_omitsNilActionURL() async throws {
        try await markClicked(actionURL: nil)

        let request = try XCTUnwrap(sessionMock.requests.first)
        let body = try XCTUnwrap(request.httpBody)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])

        XCTAssertNil(json["action_url"])
        XCTAssertEqual(json["message_id"] as? String, "msg_abc123")
    }

    func testMarkClicked_omitsEmptyActionURL() async throws {
        try await markClicked(actionURL: "")

        let request = try XCTUnwrap(sessionMock.requests.first)
        let body = try XCTUnwrap(request.httpBody)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])

        XCTAssertNil(json["action_url"])
    }

    // MARK: - Error paths

    func testMarkClicked_serverError_throwsInboxRequestFailed() async {
        sessionMock.inboxClickedStatusCode = 500

        do {
            try await markClicked()
            XCTFail("Expected request to throw")
        } catch ATTNError.inboxRequestFailed(let status) {
            XCTAssertEqual(status, 500)
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    func testMarkClicked_networkError_throwsUnderlyingError() async {
        let stubError = NSError(domain: "test", code: -1, userInfo: nil)
        sessionMock.inboxClickedError = stubError

        do {
            try await markClicked()
            XCTFail("Expected request to throw")
        } catch let error as NSError {
            XCTAssertEqual(error.domain, "test")
            XCTAssertEqual(error.code, -1)
        }
    }

    // MARK: - 204 handling

    func testMarkClicked_204WithEmptyBody_doesNotThrow() async {
        // Explicit: RFC says 204 No Content. The helper must not try to decode an empty body.
        sessionMock.inboxClickedStatusCode = 204
        sessionMock.inboxClickedResponseBody = Data()

        do {
            try await markClicked()
        } catch {
            XCTFail("204 No Content must not throw, got \(error)")
        }
    }

    func testMarkClicked_200WithBody_doesNotThrow() async {
        // Server occasionally returns 200 with a body instead of 204; helper should tolerate it.
        sessionMock.inboxClickedStatusCode = 200
        sessionMock.inboxClickedResponseBody = Data("{\"ok\": true}".utf8)

        do {
            try await markClicked()
        } catch {
            XCTFail("200 with body must not throw, got \(error)")
        }
    }
}
