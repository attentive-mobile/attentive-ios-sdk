//
//  ATTNCreativeEmailLeadTests.swift
//  attentive-ios-sdk Tests
//

import UIKit
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
        XCTAssertEqual(lead?.creativeId, "123456")
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

    func testParse_withBlankEmail_returnsNilEmail() {
        XCTAssertNil(ATTNCreativeEmailLeadParser.parse(["action": "EMAIL_LEAD", "email": "   "])?.email)
    }

    func testParse_withNonStringEmail_returnsNilEmail() {
        XCTAssertNil(ATTNCreativeEmailLeadParser.parse(["action": "EMAIL_LEAD", "email": 42])?.email)
    }

    func testParse_withStringCreativeId_returnsCreativeId() {
        let lead = ATTNCreativeEmailLeadParser.parse(["action": "EMAIL_LEAD", "creativeId": "1230751"])

        XCTAssertEqual(lead?.creativeId, "1230751")
    }

    func testParse_withNumberCreativeId_returnsStringCreativeId() {
        // WebKit bridges JSON numbers to NSNumber.
        let lead = ATTNCreativeEmailLeadParser.parse(["action": "EMAIL_LEAD", "creativeId": NSNumber(value: 1230751)])

        XCTAssertEqual(lead?.creativeId, "1230751")
    }

    func testParse_withoutCreativeId_returnsNilCreativeId() {
        XCTAssertNil(ATTNCreativeEmailLeadParser.parse(["action": "EMAIL_LEAD"])?.creativeId)
    }

    func testParse_withBlankCreativeId_returnsNilCreativeId() {
        XCTAssertNil(ATTNCreativeEmailLeadParser.parse(["action": "EMAIL_LEAD", "creativeId": " "])?.creativeId)
    }

    func testParse_withBooleanCreativeId_returnsNilCreativeId() {
        XCTAssertNil(ATTNCreativeEmailLeadParser.parse(["action": "EMAIL_LEAD", "creativeId": true])?.creativeId)
    }

    func testParse_withOtherAction_returnsNil() {
        XCTAssertNil(ATTNCreativeEmailLeadParser.parse(["action": "LEAD", "email": "user@example.com"]))
    }

    func testParse_excludesSenderOriginFromRawPayload() {
        let lead = ATTNCreativeEmailLeadParser.parse(["action": "EMAIL_LEAD", "__origin": "https://creatives.attn.tv"])

        XCTAssertNil(lead?.rawPayload["__origin"])
        XCTAssertEqual(lead?.rawPayload["action"] as? String, "EMAIL_LEAD")
    }

    // MARK: Origin

    func testIsTrustedSenderOrigin_acceptsCreativesOrigin() {
        XCTAssertTrue(ATTNCreativeEmailLeadParser.isTrustedSenderOrigin("https://creatives.attn.tv"))
    }

    func testIsTrustedSenderOrigin_rejectsOtherOrigins() {
        XCTAssertFalse(ATTNCreativeEmailLeadParser.isTrustedSenderOrigin(nil))
        XCTAssertFalse(ATTNCreativeEmailLeadParser.isTrustedSenderOrigin("null"))
        XCTAssertFalse(ATTNCreativeEmailLeadParser.isTrustedSenderOrigin("http://creatives.attn.tv"))
        XCTAssertFalse(ATTNCreativeEmailLeadParser.isTrustedSenderOrigin("https://creatives.attn.tv.example.com"))
        XCTAssertFalse(ATTNCreativeEmailLeadParser.isTrustedSenderOrigin("https://creatives.attn.tv:8443"))
    }

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

    // MARK: Routing

    func testHandleScriptMessage_withTrustedEmailLead_forwardsLeadToProvider() {
        let (handler, provider) = makeHandler()

        handler.handleScriptMessage(
            ["action": "EMAIL_LEAD", "email": "user@example.com", "creativeId": 1230751, "__origin": "https://creatives.attn.tv"],
            originProtocol: "https",
            originHost: "creatives.attn.tv"
        )

        XCTAssertEqual(provider.receivedEmailLeads.count, 1)
        XCTAssertEqual(provider.receivedEmailLeads.first?.email, "user@example.com")
        XCTAssertEqual(provider.receivedEmailLeads.first?.creativeId, "1230751")
        XCTAssertNil(provider.receivedEmailLeads.first?.rawPayload["__origin"])
    }

    func testHandleScriptMessage_withUntrustedFrameOrigin_dropsLead() {
        let (handler, provider) = makeHandler()

        handler.handleScriptMessage(
            ["action": "EMAIL_LEAD", "email": "user@example.com", "__origin": "https://creatives.attn.tv"],
            originProtocol: "https",
            originHost: "example.com"
        )

        XCTAssertTrue(provider.receivedEmailLeads.isEmpty)
    }

    func testHandleScriptMessage_withUntrustedSenderOrigin_dropsLead() {
        // A cross-origin child frame posting to the creative page: the frame that calls the
        // message handler is the creative page, but the original sender isn't.
        let (handler, provider) = makeHandler()

        handler.handleScriptMessage(
            ["action": "EMAIL_LEAD", "email": "forged@example.com", "__origin": "null"],
            originProtocol: "https",
            originHost: "creatives.attn.tv"
        )

        XCTAssertTrue(provider.receivedEmailLeads.isEmpty)
    }

    func testHandleScriptMessage_withoutSenderOrigin_dropsLead() {
        let (handler, provider) = makeHandler()

        handler.handleScriptMessage(
            ["action": "EMAIL_LEAD", "email": "user@example.com"],
            originProtocol: "https",
            originHost: "creatives.attn.tv"
        )

        XCTAssertTrue(provider.receivedEmailLeads.isEmpty)
    }

    func testMakeWebView_injectedListenerForwardsSenderOrigin() {
        let (handler, _) = makeHandler()

        let scripts = handler.makeWebView().configuration.userContentController.userScripts

        XCTAssertTrue(scripts.contains { $0.source.contains("__origin: event.origin") })
    }

    func testHandleScriptMessage_withOtherAction_doesNotForwardLead() {
        let (handler, provider) = makeHandler()

        handler.handleScriptMessage(
            ["action": "IMPRESSION", "email": "user@example.com"],
            originProtocol: "https",
            originHost: "creatives.attn.tv"
        )

        XCTAssertTrue(provider.receivedEmailLeads.isEmpty)
    }

    // MARK: Delivery

    func testDidReceiveCreativeEmailLead_callsHandlerOnMainQueue() {
        let sdk = ATTNSDK(api: ATTNAPISpy(domain: "TEST_DOMAIN"))
        let lead = ATTNCreativeEmailLead(email: "user@example.com", creativeId: "1230751", rawPayload: [:])
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

        sdk.didReceiveCreativeEmailLead(ATTNCreativeEmailLead(email: "user@example.com", creativeId: "1230751", rawPayload: [:]))
    }

    // MARK: Helpers

    private func makeHandler() -> (ATTNWebViewHandler, MockWebViewProvider) {
        let provider = MockWebViewProvider()
        provider.parentView = UIView()
        let handler = ATTNWebViewHandler(
            webViewProvider: provider,
            creativeUrlBuilder: MockCreativeUrlProvider(),
            stateManager: ATTNCreativeStateManager(),
            launchTimeoutInterval: 3600
        )
        return (handler, provider)
    }
}
