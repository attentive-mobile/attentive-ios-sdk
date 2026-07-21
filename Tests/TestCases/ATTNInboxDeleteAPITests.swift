//
//  ATTNInboxDeleteAPITests.swift
//  attentive-ios-sdk Tests
//

import XCTest
@testable import ATTNSDKFramework

final class ATTNInboxDeleteAPITests: XCTestCase {
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

    private func deleteMessage(
        pushToken: String = "abc123devicetoken",
        messageId: String = "msg-1",
        identity: ATTNUserIdentity? = nil
    ) async throws {
        try await api.deleteInboxMessage(
            pushToken: pushToken,
            visitorId: (identity ?? userIdentity).visitorId,
            messageId: messageId
        )
    }

    func testDelete_success_hitsExpectedURL() async throws {
        try await deleteMessage(messageId: "msg_abc123")

        XCTAssertTrue(sessionMock.didCallInboxDeleteApi)
        XCTAssertEqual(sessionMock.urlCalls.count, 1)
        XCTAssertEqual(
            sessionMock.urlCalls[0].absoluteString,
            "https://mobile.attentivemobile.com/inbox/messages/msg_abc123"
        )
    }

    func testDelete_sendsExpectedRequest() async throws {
        try await deleteMessage(messageId: "msg-1")

        let request = try XCTUnwrap(sessionMock.requests.first)
        XCTAssertEqual(request.httpMethod, "DELETE")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")

        let body = try XCTUnwrap(request.httpBody)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])

        XCTAssertEqual(json["c"] as? String, testDomain)
        XCTAssertEqual(json["visitor_id"] as? String, userIdentity.visitorId)
        XCTAssertEqual(json["push_token"] as? String, "apns:abc123devicetoken")
    }

    func testDelete_omitsEmptyPushToken() async throws {
        try await deleteMessage(pushToken: "")

        let request = try XCTUnwrap(sessionMock.requests.first)
        let body = try XCTUnwrap(request.httpBody)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])

        XCTAssertNil(json["push_token"])
        XCTAssertEqual(json["c"] as? String, testDomain)
        XCTAssertEqual(json["visitor_id"] as? String, userIdentity.visitorId)
    }

    func testDelete_percentEncodesMessageIdInPath() async throws {
        try await deleteMessage(messageId: "msg with spaces/and slashes")

        XCTAssertEqual(sessionMock.urlCalls.count, 1)
        let urlString = sessionMock.urlCalls[0].absoluteString
        XCTAssertTrue(
            urlString.hasPrefix("https://mobile.attentivemobile.com/inbox/messages/"),
            "URL should be scoped under /inbox/messages/, got \(urlString)"
        )
        XCTAssertFalse(urlString.contains(" "), "Raw spaces must not appear in the URL path")
    }

    func testDelete_escapesForwardSlashesInMessageId() async throws {
        // The message id occupies a single path segment. A slash in the id must be percent-
        // encoded so it doesn't split the segment and address a different route.
        try await deleteMessage(messageId: "abc/def")

        XCTAssertEqual(sessionMock.urlCalls.count, 1)
        XCTAssertEqual(
            sessionMock.urlCalls[0].absoluteString,
            "https://mobile.attentivemobile.com/inbox/messages/abc%2Fdef"
        )
    }

    func testDelete_serverError_throwsInboxRequestFailed() async {
        sessionMock.inboxDeleteStatusCode = 500

        do {
            try await deleteMessage()
            XCTFail("Expected request to throw")
        } catch ATTNError.inboxRequestFailed(let status) {
            XCTAssertEqual(status, 500)
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    func testDelete_networkError_throwsUnderlyingError() async {
        let stubError = NSError(domain: "test", code: -1, userInfo: nil)
        sessionMock.inboxDeleteError = stubError

        do {
            try await deleteMessage()
            XCTFail("Expected request to throw")
        } catch let error as NSError {
            XCTAssertEqual(error.domain, "test")
            XCTAssertEqual(error.code, -1)
        }
    }
}
