//
//  ATTNInboxAPITests.swift
//  attentive-ios-sdk Tests
//
//  Created by Adela Gao on 6/4/26.
//

import XCTest
@testable import ATTNSDKFramework

final class ATTNInboxAPITests: XCTestCase {
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
        pushToken: String = "fcm:abc123",
        email: String? = nil,
        phone: String? = nil,
        identity: ATTNUserIdentity? = nil
    ) async throws -> Int {
        try await api.fetchInboxUnreadCount(
            pushToken: pushToken,
            email: email,
            phone: phone,
            userIdentity: identity ?? userIdentity
        )
    }

    func testFetchInboxUnreadCount_success_returnsServerCount() async throws {
        sessionMock.inboxUnreadCountResponseBody = Data("{\"unread_count\": 7}".utf8)

        let count = try await fetch(email: "user@example.com", phone: "+15551234567")

        XCTAssertEqual(count, 7)
        XCTAssertTrue(sessionMock.didCallInboxUnreadCountApi)
        XCTAssertEqual(sessionMock.urlCalls.count, 1)
        XCTAssertEqual(sessionMock.urlCalls[0].absoluteString, "https://mobile.attentivemobile.com/inbox/messages/unread/count")
    }

    func testFetchInboxUnreadCount_sendsExpectedRequestBody() async throws {
        _ = try await fetch(email: "user@example.com", phone: "+15551234567")

        let request = try XCTUnwrap(sessionMock.requests.first)
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")

        let body = try XCTUnwrap(request.httpBody)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])

        XCTAssertEqual(json["visitor_id"] as? String, userIdentity.visitorId)
        XCTAssertEqual(json["push_token"] as? String, "fcm:abc123")
        XCTAssertEqual(json["email"] as? String, "user@example.com")
        XCTAssertEqual(json["phone"] as? String, "+15551234567")
    }

    func testFetchInboxUnreadCount_omitsEmptyOptionalFields() async throws {
        let emptyIdentity = ATTNUserIdentity()
        _ = try await fetch(pushToken: "", identity: emptyIdentity)

        let request = try XCTUnwrap(sessionMock.requests.first)
        let body = try XCTUnwrap(request.httpBody)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])

        XCTAssertEqual(json["visitor_id"] as? String, emptyIdentity.visitorId)
        XCTAssertNil(json["push_token"])
        XCTAssertNil(json["email"])
        XCTAssertNil(json["phone"])
    }

    func testFetchInboxUnreadCount_serverError_throwsInboxRequestFailed() async {
        sessionMock.inboxUnreadCountStatusCode = 500

        do {
            _ = try await fetch()
            XCTFail("Expected request to throw")
        } catch ATTNError.inboxRequestFailed(let status) {
            XCTAssertEqual(status, 500)
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    func testFetchInboxUnreadCount_malformedBody_throwsDecodeFailed() async {
        sessionMock.inboxUnreadCountResponseBody = Data("not json".utf8)

        do {
            _ = try await fetch()
            XCTFail("Expected request to throw")
        } catch ATTNError.inboxResponseDecodeFailed {
            // expected
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    func testFetchInboxUnreadCount_networkError_throwsUnderlyingError() async {
        let stubError = NSError(domain: "test", code: -1, userInfo: nil)
        sessionMock.inboxUnreadCountError = stubError

        do {
            _ = try await fetch()
            XCTFail("Expected request to throw")
        } catch let error as NSError {
            XCTAssertEqual(error.domain, "test")
            XCTAssertEqual(error.code, -1)
        }
    }
}
