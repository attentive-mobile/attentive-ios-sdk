//
//  ATTNCreativeEmailLeadTests.swift
//  attentive-ios-sdk Tests
//

import XCTest
@testable import ATTNSDKFramework

final class ATTNCreativeEmailLeadTests: XCTestCase {

    // MARK: Parsing

    func testParse_withEmail_returnsEmailAndRawPayload() {
        // Shape of a real creative submission.
        let body: [String: Any] = [
            "action": "EMAIL_LEAD",
            "email": "user@example.com",
            "creativeId": 123456,
            "visitorId": "TEST_VISITOR_ID"
        ]

        let lead = ATTNCreativeEmailLeadParser.parse(body)

        XCTAssertEqual(lead?.email, "user@example.com")
        XCTAssertEqual(lead?.rawPayload["creativeId"] as? Int, 123456)
        XCTAssertEqual(lead?.rawPayload["visitorId"] as? String, "TEST_VISITOR_ID")
    }

    func testParse_keepsEmailAsSent() {
        let lead = ATTNCreativeEmailLeadParser.parse(["action": "EMAIL_LEAD", "email": "User@Example.COM"])

        XCTAssertEqual(lead?.email, "User@Example.COM")
    }

    func testParse_withoutEmail_returnsNilEmail() {
        let lead = ATTNCreativeEmailLeadParser.parse(["action": "EMAIL_LEAD"])

        XCTAssertNotNil(lead)
        XCTAssertNil(lead?.email)
    }

    func testParse_withEmptyEmail_returnsNilEmail() {
        XCTAssertNil(ATTNCreativeEmailLeadParser.parse(["action": "EMAIL_LEAD", "email": ""])?.email)
    }

    func testParse_withNonStringEmail_returnsNilEmail() {
        XCTAssertNil(ATTNCreativeEmailLeadParser.parse(["action": "EMAIL_LEAD", "email": 42])?.email)
    }

    func testParse_withOtherAction_returnsNil() {
        XCTAssertNil(ATTNCreativeEmailLeadParser.parse(["action": "LEAD", "email": "user@example.com"]))
    }

    // MARK: Origin

    func testIsTrustedOrigin_acceptsCreativesHostOverHttps() {
        XCTAssertTrue(ATTNCreativeEmailLeadParser.isTrustedOrigin(protocol: "https", host: "creatives.attn.tv"))
    }

    func testIsTrustedOrigin_rejectsOtherHosts() {
        XCTAssertFalse(ATTNCreativeEmailLeadParser.isTrustedOrigin(protocol: "https", host: "example.com"))
        XCTAssertFalse(ATTNCreativeEmailLeadParser.isTrustedOrigin(protocol: "https", host: "creatives.attn.tv.example.com"))
    }

    func testIsTrustedOrigin_rejectsHttp() {
        XCTAssertFalse(ATTNCreativeEmailLeadParser.isTrustedOrigin(protocol: "http", host: "creatives.attn.tv"))
    }

    // MARK: Delivery

    func testDidReceiveCreativeEmailLead_callsHandlerOnMainQueue() {
        let sdk = ATTNSDK(api: ATTNAPISpy(domain: "TEST_DOMAIN"))
        let lead = ATTNCreativeEmailLead(email: "user@example.com", rawPayload: [:])
        let delivered = expectation(description: "handler called")
        sdk.creativeEmailLeadHandler = { received in
            XCTAssertTrue(Thread.isMainThread)
            XCTAssertTrue(received === lead)
            delivered.fulfill()
        }

        DispatchQueue.global().async {
            sdk.didReceiveCreativeEmailLead(lead)
        }

        wait(for: [delivered], timeout: 5)
    }

    func testDidReceiveCreativeEmailLead_withoutHandler_doesNotCrash() {
        let sdk = ATTNSDK(api: ATTNAPISpy(domain: "TEST_DOMAIN"))

        sdk.didReceiveCreativeEmailLead(ATTNCreativeEmailLead(email: "user@example.com", rawPayload: [:]))
    }
}
