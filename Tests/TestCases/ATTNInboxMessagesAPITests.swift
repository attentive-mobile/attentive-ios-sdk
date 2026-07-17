//
//  ATTNInboxMessagesAPITests.swift
//  attentive-ios-sdk Tests
//
//  Created by Adela Gao on 7/6/26.
//

import XCTest
@testable import ATTNSDKFramework

final class ATTNInboxMessagesAPITests: XCTestCase {
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

    private func fetch(
        pushToken: String = "abc123",
        email: String? = nil,
        phone: String? = nil,
        pageSize: Int = 20,
        pageToken: String? = nil,
        identity: ATTNUserIdentity? = nil
    ) async throws -> InboxResponse {
        try await api.fetchInboxMessages(
            pushToken: pushToken,
            email: email,
            phone: phone,
            visitorId: (identity ?? userIdentity).visitorId,
            pageSize: pageSize,
            pageToken: pageToken
        )
    }

    private static let successBody = """
    {
      "messages": [
        {
          "inbox_message_id": "msg_abc123",
          "title": "20% off today",
          "body": "Use code SAVE20 at checkout",
          "image_url": "https://cdn.example.com/promo.jpg",
          "action_url": "myapp://products/sale",
          "sent_at": "2026-05-01T12:00:00Z",
          "expires_at": "2027-05-01T12:00:00Z",
          "is_read": false,
          "read_at": null
        }
      ],
      "next_page_token": "xyz789"
    }
    """

    func testFetchInboxMessages_success_decodesMessagesAndNextPageToken() async throws {
        sessionMock.inboxMessagesResponseBody = Data(Self.successBody.utf8)

        let response = try await fetch(email: "user@example.com", phone: "+15551234567")

        XCTAssertEqual(response.messages.count, 1)
        XCTAssertEqual(response.nextPageToken, "xyz789")
        XCTAssertTrue(sessionMock.didCallInboxMessagesApi)
        XCTAssertEqual(sessionMock.urlCalls.count, 1)
        XCTAssertEqual(sessionMock.urlCalls[0].absoluteString, "https://mobile.attentivemobile.com/inbox/messages")

        let message = try XCTUnwrap(response.messages.first)
        XCTAssertEqual(message.id, "msg_abc123")
        XCTAssertEqual(message.title, "20% off today")
        XCTAssertEqual(message.body, "Use code SAVE20 at checkout")
        XCTAssertEqual(message.imageURLString, "https://cdn.example.com/promo.jpg")
        XCTAssertEqual(message.actionURLString, "myapp://products/sale")
        XCTAssertFalse(message.isRead)
        XCTAssertNil(message.readAt)
        XCTAssertNotNil(message.expiresAt)
        // Client-side default because the server response has no `style` field.
        XCTAssertEqual(message.style, .small)
    }

    func testFetchInboxMessages_sendsExpectedRequestBody() async throws {
        _ = try await fetch(email: "user@example.com", phone: "+15551234567", pageSize: 20, pageToken: "cursor-abc")

        let request = try XCTUnwrap(sessionMock.requests.first)
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")

        let body = try XCTUnwrap(request.httpBody)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])

        XCTAssertEqual(json["c"] as? String, testDomain)
        XCTAssertEqual(json["visitor_id"] as? String, userIdentity.visitorId)
        XCTAssertEqual(json["push_token"] as? String, "apns:abc123", "SDK must prefix the raw device token with the APNs transport scheme")
        XCTAssertEqual(json["email"] as? String, "user@example.com")
        XCTAssertEqual(json["phone"] as? String, "+15551234567")
        XCTAssertEqual(json["page_size"] as? Int, 20)
        XCTAssertEqual(json["page_token"] as? String, "cursor-abc")
    }

    func testFetchInboxMessages_omitsEmptyOptionalFields() async throws {
        let emptyIdentity = ATTNUserIdentity()
        _ = try await fetch(pushToken: "", pageToken: nil, identity: emptyIdentity)

        let request = try XCTUnwrap(sessionMock.requests.first)
        let body = try XCTUnwrap(request.httpBody)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])

        XCTAssertEqual(json["c"] as? String, testDomain)
        XCTAssertEqual(json["visitor_id"] as? String, emptyIdentity.visitorId)
        XCTAssertNil(json["push_token"])
        XCTAssertNil(json["email"])
        XCTAssertNil(json["phone"])
        XCTAssertNil(json["page_token"])
    }

    func testFetchInboxMessages_serverError_throwsInboxRequestFailed() async {
        sessionMock.inboxMessagesStatusCode = 500

        do {
            _ = try await fetch()
            XCTFail("Expected request to throw")
        } catch ATTNError.inboxRequestFailed(let status) {
            XCTAssertEqual(status, 500)
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    func testFetchInboxMessages_malformedBody_throwsDecodeFailed() async {
        sessionMock.inboxMessagesResponseBody = Data("not json".utf8)

        do {
            _ = try await fetch()
            XCTFail("Expected request to throw")
        } catch ATTNError.inboxResponseDecodeFailed {
            // expected
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    func testFetchInboxMessages_networkError_throwsUnderlyingError() async {
        let stubError = NSError(domain: "test", code: -1, userInfo: nil)
        sessionMock.inboxMessagesError = stubError

        do {
            _ = try await fetch()
            XCTFail("Expected request to throw")
        } catch let error as NSError {
            XCTAssertEqual(error.domain, "test")
            XCTAssertEqual(error.code, -1)
        }
    }
}
