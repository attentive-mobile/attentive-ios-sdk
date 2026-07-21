//
//  ATTNInboxMarkReadAPITests.swift
//  attentive-ios-sdk Tests
//

import XCTest
@testable import ATTNSDKFramework

final class ATTNInboxMarkReadAPITests: XCTestCase {
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

    private func markRead(
        pushToken: String = "abc123devicetoken",
        messageIds: [String] = ["msg-1"],
        identity: ATTNUserIdentity? = nil
    ) async throws -> UpdateReadStatusResponse {
        try await api.markMessagesRead(
            pushToken: pushToken,
            visitorId: (identity ?? userIdentity).visitorId,
            messageIds: messageIds
        )
    }

    func testMarkRead_success_decodesServerResponse() async throws {
        sessionMock.inboxMarkReadResponseBody = Data("""
        {
          "messages": [
            {"message_id": "msg-1", "is_read": true},
            {"message_id": "msg-2", "is_read": true}
          ],
          "unread_count": 3
        }
        """.utf8)

        let response = try await markRead(messageIds: ["msg-1", "msg-2"])

        XCTAssertEqual(response.unreadCount, 3)
        XCTAssertEqual(response.messages.count, 2)
        XCTAssertEqual(response.messages.first?.messageId, "msg-1")
        XCTAssertTrue(response.messages.first?.isRead ?? false)
        XCTAssertTrue(sessionMock.didCallInboxMarkReadApi)
        XCTAssertEqual(sessionMock.urlCalls.count, 1)
        XCTAssertEqual(sessionMock.urlCalls[0].absoluteString, "https://mobile.attentivemobile.com/inbox/messages/read")
    }

    func testMarkRead_sendsExpectedRequest() async throws {
        _ = try await markRead(messageIds: ["msg-1", "msg-2"])

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

    func testMarkRead_omitsEmptyPushToken() async throws {
        _ = try await markRead(pushToken: "")

        let request = try XCTUnwrap(sessionMock.requests.first)
        let body = try XCTUnwrap(request.httpBody)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])

        XCTAssertNil(json["push_token"])
        XCTAssertEqual(json["c"] as? String, testDomain, "clientDomainPrefix is required even when push_token is omitted")
        XCTAssertEqual(json["visitor_id"] as? String, userIdentity.visitorId)
    }

    func testMarkRead_serverError_throwsInboxRequestFailed() async {
        sessionMock.inboxMarkReadStatusCode = 500

        do {
            _ = try await markRead()
            XCTFail("Expected request to throw")
        } catch ATTNError.inboxRequestFailed(let status) {
            XCTAssertEqual(status, 500)
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    func testMarkRead_malformedBody_throwsDecodeFailed() async {
        sessionMock.inboxMarkReadResponseBody = Data("not json".utf8)

        do {
            _ = try await markRead()
            XCTFail("Expected request to throw")
        } catch ATTNError.inboxResponseDecodeFailed {
            // expected
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    func testMarkRead_networkError_throwsUnderlyingError() async {
        let stubError = NSError(domain: "test", code: -1, userInfo: nil)
        sessionMock.inboxMarkReadError = stubError

        do {
            _ = try await markRead()
            XCTFail("Expected request to throw")
        } catch let error as NSError {
            XCTAssertEqual(error.domain, "test")
            XCTAssertEqual(error.code, -1)
        }
    }
}
