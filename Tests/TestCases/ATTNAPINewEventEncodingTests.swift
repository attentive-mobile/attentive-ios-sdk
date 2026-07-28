//
//  ATTNAPINewEventEncodingTests.swift
//  attentive-ios-sdk Tests
//
//  Regression tests for MSDK-441: the `/mobile` v2 event endpoint posts JSON as
//  a `application/x-www-form-urlencoded` body. The percent-encoding allow-set must
//  escape the sub-delims (`&`, `=`, `+`, `#`) that separate form fields; otherwise
//  a raw `&` in a product name (e.g. "Grab & Go") splits the body and truncates
//  the `d` value, causing AEH to reject the event with 422.
//

import XCTest
@testable import ATTNSDKFramework

final class ATTNAPINewEventEncodingTests: XCTestCase {
    let testDomain = "test.attentivemobile.com"

    private func sendAddToCartAndReturnBody(productName: String) -> String {
        let sessionMock = NSURLSessionMock()
        let api = ATTNAPI(domain: testDomain, urlSession: sessionMock)
        let identity = ATTNTestEventUtils.buildUserIdentity()
        let product = ATTNProduct(
            productId: "123",
            name: productName,
            price: "10.00",
            quantity: 1
        )
        let metadata = ATTNAddToCartMetadata(product: product, currency: "USD")
        let event = ATTNBaseEvent(
            visitorId: identity.visitorId,
            version: ATTNConstants.sdkVersion,
            attentiveDomain: testDomain,
            locationHref: nil,
            referrer: "",
            eventType: .addToCart,
            timestamp: "2026-07-28T00:00:00Z",
            identifiers: ATTNIdentifiers(encryptedEmail: nil, encryptedPhone: nil, otherIdentifiers: nil),
            eventMetadata: metadata,
            genericMetadata: nil,
            sourceType: "mobile",
            appSdk: "iOS"
        )
        let eventRequest = ATTNEventRequest(metadata: [:], eventNameAbbreviation: ATTNEventTypes.addToCart)

        api.sendNewEvent(event: event, eventRequest: eventRequest, userIdentity: identity, callback: nil)

        guard let bodyData = sessionMock.requests.last?.httpBody,
              let body = String(data: bodyData, encoding: .utf8) else {
            XCTFail("Expected /mobile request to have a UTF-8 httpBody")
            return ""
        }
        return body
    }

    /// A well-formed form-urlencoded body should parse to exactly one `d` field
    /// whose value, once percent-decoded, contains the original product name verbatim.
    private func assertBodyIsSingleFormFieldRoundTrippingName(_ body: String, expectedName: String, file: StaticString = #filePath, line: UInt = #line) {
        // Parse the body via URLComponents to mirror what a form-urlencoded parser does.
        var components = URLComponents()
        components.percentEncodedQuery = body
        let items = components.queryItems ?? []

        XCTAssertEqual(items.count, 1, "Body must be a single form field; found \(items.map(\.name))", file: file, line: line)
        XCTAssertEqual(items.first?.name, "d", "Form field must be named `d`", file: file, line: line)

        guard let decodedJson = items.first?.value else {
            XCTFail("`d` field has no decoded value", file: file, line: line)
            return
        }

        // JSON should be well-formed and contain the original name string verbatim.
        guard let jsonData = decodedJson.data(using: .utf8),
              let parsed = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
            XCTFail("Decoded `d` value is not valid JSON: \(decodedJson)", file: file, line: line)
            return
        }
        let metadata = parsed["eventMetadata"] as? [String: Any]
        let product = metadata?["product"] as? [String: Any]
        XCTAssertEqual(product?["name"] as? String, expectedName, "Product name round-trip failed", file: file, line: line)
    }

    // MARK: - Regression: sub-delim characters must be escaped in body

    func testSendNewEvent_productNameWithAmpersand_bodyIsSingleFormFieldAndRoundTrips() {
        let body = sendAddToCartAndReturnBody(productName: "Grab & Go")

        // Raw & must NOT appear inside the encoded `d` value — it would split the body.
        // The only `&` allowed in a well-formed body would be between two form fields,
        // but we only have one field.
        XCTAssertFalse(body.contains("&"), "Raw `&` splits the form body: \(body)")
        assertBodyIsSingleFormFieldRoundTrippingName(body, expectedName: "Grab & Go")
    }

    func testSendNewEvent_productNameWithEquals_bodyIsSingleFormFieldAndRoundTrips() {
        let body = sendAddToCartAndReturnBody(productName: "Buy 1 = Get 1")
        // The single `=` between the `d` key and its value is allowed; anything past that
        // must be percent-encoded, so no additional `=` should appear.
        let firstEquals = body.firstIndex(of: "=")
        XCTAssertNotNil(firstEquals)
        let afterFirstEquals = body[body.index(after: firstEquals!)...]
        XCTAssertFalse(afterFirstEquals.contains("="), "Extra `=` in body value: \(body)")
        assertBodyIsSingleFormFieldRoundTrippingName(body, expectedName: "Buy 1 = Get 1")
    }

    func testSendNewEvent_productNameWithPlus_bodyIsSingleFormFieldAndRoundTrips() {
        // A raw `+` in a form-urlencoded body is interpreted by many parsers as a
        // literal space — decoding "Grab+Go" as "Grab Go" would corrupt the name.
        let body = sendAddToCartAndReturnBody(productName: "Grab+Go")
        XCTAssertFalse(body.dropFirst(2).contains("+"), "Raw `+` in body value would decode as space: \(body)")
        assertBodyIsSingleFormFieldRoundTrippingName(body, expectedName: "Grab+Go")
    }

    func testSendNewEvent_productNameWithHash_bodyIsSingleFormFieldAndRoundTrips() {
        let body = sendAddToCartAndReturnBody(productName: "Item #42")
        XCTAssertFalse(body.contains("#"), "Raw `#` in body may be treated as fragment: \(body)")
        assertBodyIsSingleFormFieldRoundTrippingName(body, expectedName: "Item #42")
    }

    func testSendNewEvent_productNameWithMultipleSubDelims_bodyRoundTrips() {
        let body = sendAddToCartAndReturnBody(productName: "A & B = C + D #1")
        assertBodyIsSingleFormFieldRoundTrippingName(body, expectedName: "A & B = C + D #1")
    }

    // MARK: - Regression: sample product names from the SEV-4899 report

    func testSendNewEvent_carterSampleNames_bodyRoundTrips() {
        let samples = [
            "Grab & Go Snacks",
            "Ribbed Top & Shorts Set",
            "Bodysuit & Pant Set"
        ]
        for name in samples {
            let body = sendAddToCartAndReturnBody(productName: name)
            assertBodyIsSingleFormFieldRoundTrippingName(body, expectedName: name)
        }
    }

    // MARK: - Non-regression: safe characters still round-trip

    func testSendNewEvent_productNameWithSafeCharacters_bodyRoundTrips() {
        let body = sendAddToCartAndReturnBody(productName: "Classic T-Shirt (Blue) - Size L")
        assertBodyIsSingleFormFieldRoundTrippingName(body, expectedName: "Classic T-Shirt (Blue) - Size L")
    }

    // MARK: - Non-regression: request shape

    func testSendNewEvent_setsFormUrlEncodedContentTypeHeader() {
        let sessionMock = NSURLSessionMock()
        let api = ATTNAPI(domain: testDomain, urlSession: sessionMock)
        let identity = ATTNTestEventUtils.buildUserIdentity()
        let product = ATTNProduct(productId: "123", name: "Test", price: "10.00", quantity: 1)
        let metadata = ATTNAddToCartMetadata(product: product, currency: "USD")
        let event = ATTNBaseEvent(
            visitorId: identity.visitorId,
            version: ATTNConstants.sdkVersion,
            attentiveDomain: testDomain,
            locationHref: nil,
            referrer: "",
            eventType: .addToCart,
            timestamp: "2026-07-28T00:00:00Z",
            identifiers: ATTNIdentifiers(encryptedEmail: nil, encryptedPhone: nil, otherIdentifiers: nil),
            eventMetadata: metadata,
            genericMetadata: nil,
            sourceType: "mobile",
            appSdk: "iOS"
        )
        let eventRequest = ATTNEventRequest(metadata: [:], eventNameAbbreviation: ATTNEventTypes.addToCart)

        api.sendNewEvent(event: event, eventRequest: eventRequest, userIdentity: identity, callback: nil)

        let contentType = sessionMock.requests.last?.value(forHTTPHeaderField: "Content-Type")
        XCTAssertEqual(contentType, "application/x-www-form-urlencoded; charset=utf-8")
    }
}
