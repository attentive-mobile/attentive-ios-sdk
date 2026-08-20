//
//  ATTNv2DeeplinkTests.swift
//  attentive-ios-sdk Tests
//
//  Regression tests for MSDK-441: the v2 endpoint dropped the `pd` (deeplink)
//  query param on ProductView and AddToCart because `sendNewEventInternal`
//  built its `ATTNEventRequest` without threading `deeplink` through.
//

import XCTest
@testable import ATTNSDKFramework

final class ATTNv2DeeplinkTests: XCTestCase {

    var sdk: ATTNSDK!
    var apiSpy: ATTNAPISpy!

    override func setUp() {
        super.setUp()
        apiSpy = ATTNAPISpy(domain: "test.attentivemobile.com")
        sdk = ATTNSDK(api: apiSpy)
        sdk._useV2Endpoint = true
    }

    override func tearDown() {
        sdk = nil
        apiSpy = nil
        super.tearDown()
    }

    // MARK: - ProductView

    func testProductViewV2_withDeeplink_setsDeeplinkOnEventRequest() {
        let event = ATTNTestEventUtils.buildProductView()
        event.deeplink = "myapp://product/123"

        sdk.send(event: event)

        XCTAssertTrue(apiSpy.sendNewEventWasCalled)
        XCTAssertEqual(apiSpy.lastEventRequest?.deeplink, "myapp://product/123")
    }

    func testProductViewV2_withoutDeeplink_leavesDeeplinkNilOnEventRequest() {
        let event = ATTNTestEventUtils.buildProductView()

        sdk.send(event: event)

        XCTAssertTrue(apiSpy.sendNewEventWasCalled)
        XCTAssertNil(apiSpy.lastEventRequest?.deeplink)
    }

    // MARK: - AddToCart

    func testAddToCartV2_withDeeplink_setsDeeplinkOnEventRequest() {
        let event = ATTNTestEventUtils.buildAddToCart()
        event.deeplink = "myapp://cart"

        sdk.send(event: event)

        XCTAssertTrue(apiSpy.sendNewEventWasCalled)
        XCTAssertEqual(apiSpy.lastEventRequest?.deeplink, "myapp://cart")
    }

    func testAddToCartV2_withoutDeeplink_leavesDeeplinkNilOnEventRequest() {
        let event = ATTNTestEventUtils.buildAddToCart()

        sdk.send(event: event)

        XCTAssertTrue(apiSpy.sendNewEventWasCalled)
        XCTAssertNil(apiSpy.lastEventRequest?.deeplink)
    }

    // MARK: - End-to-end URL: pd query param appears when deeplink is set

    /// Combines the internal plumbing (via `send(event:)`) with the URL builder
    /// so we catch a regression at either layer that would strip `pd`.
    func testProductViewV2_withDeeplink_producesPdQueryParamOnUrl() {
        let event = ATTNTestEventUtils.buildProductView()
        event.deeplink = "myapp://product/456"

        sdk.send(event: event)

        guard let eventRequest = apiSpy.lastEventRequest else {
            XCTFail("Expected sendNewEvent to be called with an ATTNEventRequest")
            return
        }
        let urlProvider = ATTNEventURLProvider()
        let url = urlProvider.buildNewEventEndpointUrl(
            for: eventRequest,
            userIdentity: sdk.userIdentity,
            domain: "test.attentivemobile.com"
        )
        XCTAssertNotNil(url)
        let queryItems = ATTNTestEventUtils.getQueryItemsFromUrl(url: url!)
        XCTAssertEqual(queryItems["pd"], "myapp://product/456")
    }
}
