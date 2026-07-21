//
//  ATTNInboxMarkUnreadAPITests.swift
//  attentive-ios-sdk Tests
//

import XCTest
@testable import ATTNSDKFramework

final class ATTNInboxMarkUnreadAPITests: XCTestCase {
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

    private func markUnread(
        pushToken: String = "abc123devicetoken",
        messageIds: [String] = ["msg-1"],
        identity: ATTNUserIdentity? = nil
    ) async throws -> UpdateReadStatusResponse {
        try await api.markMessagesUnread(
            pushToken: pushToken,
            visitorId: (identity ?? userIdentity).visitorId,
            messageIds: messageIds
        )
    }

    func testMarkUnread_success_decodesServerResponse() async throws {
        sessionMock.inboxMarkUnreadResponseBody = Data("""
        {
          "messages": [
            {"message_id": "msg-1", "is_read": false},
            {"message_id": "msg-2", "is_read": false}
          ],
          "unread_count": 4
        }
        """.utf8)

        let response = try await markUnread(messageIds: ["msg-1", "msg-2"])

        XCTAssertEqual(response.unreadCount, 4)
        XCTAssertEqual(response.messages.count, 2)
        XCTAssertEqual(response.messages.first?.messageId, "msg-1")
        XCTAssertFalse(response.messages.first?.isRead ?? true)
        XCTAssertTrue(sessionMock.didCallInboxMarkUnreadApi)
        XCTAssertEqual(sessionMock.urlCalls.count, 1)
        XCTAssertEqual(sessionMock.urlCalls[0].absoluteString, "https://mobile.attentivemobile.com/inbox/messages/unread")
    }

    func testMarkUnread_sendsExpectedRequest() async throws {
        _ = try await markUnread(messageIds: ["msg-1", "msg-2"])

        let request = try XCTUnwrap(sessionMock.requests.first)
        XCTAssertEqual(request.httpMethod, "PATCH")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")

        let body = try XCTUnwrap(request.httpBody)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])

        XCTAssertEqual(json["c"] as? String, testDomain, "server requires clientDomainPrefix for company resolution")
        XCTAssertEqual(json["visitor_id"] as? String, userIdentity.visitorId)
        // Push tokens are namespaced by transport for the inbox backend.
        XCTAssertEqual(json["push_token"] as? String, "apns:abc123devicetoken")
        XCTAssertEqual(json["message_ids"] as? [String], ["msg-1", "msg-2"])
        // Contract does not carry email/phone.
        XCTAssertNil(json["email"])
        XCTAssertNil(json["phone"])
    }

    func testMarkUnread_omitsEmptyPushToken() async throws {
        _ = try await markUnread(pushToken: "")

        let request = try XCTUnwrap(sessionMock.requests.first)
        let body = try XCTUnwrap(request.httpBody)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])

        XCTAssertNil(json["push_token"])
        XCTAssertEqual(json["c"] as? String, testDomain, "clientDomainPrefix is required even when push_token is omitted")
        XCTAssertEqual(json["visitor_id"] as? String, userIdentity.visitorId)
    }

    func testMarkUnread_serverError_throwsInboxRequestFailed() async {
        sessionMock.inboxMarkUnreadStatusCode = 500

        do {
            _ = try await markUnread()
            XCTFail("Expected request to throw")
        } catch ATTNError.inboxRequestFailed(let status) {
            XCTAssertEqual(status, 500)
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    func testMarkUnread_malformedBody_throwsDecodeFailed() async {
        sessionMock.inboxMarkUnreadResponseBody = Data("not json".utf8)

        do {
            _ = try await markUnread()
            XCTFail("Expected request to throw")
        } catch ATTNError.inboxResponseDecodeFailed {
            // expected
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    func testMarkUnread_networkError_throwsUnderlyingError() async {
        let stubError = NSError(domain: "test", code: -1, userInfo: nil)
        sessionMock.inboxMarkUnreadError = stubError

        do {
            _ = try await markUnread()
            XCTFail("Expected request to throw")
        } catch let error as NSError {
            XCTAssertEqual(error.domain, "test")
            XCTAssertEqual(error.code, -1)
        }
    }
}
