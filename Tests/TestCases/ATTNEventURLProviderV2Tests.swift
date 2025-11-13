//
//  ATTNEventURLProviderV2Tests.swift
//  attentive-ios-sdk Tests
//
//  Created by Adela Gao on 11/10/25.
//

import XCTest
@testable import ATTNSDKFramework

final class ATTNEventURLProviderV2Tests: XCTestCase {

  var urlProvider: ATTNEventURLProvider!
  var userIdentity: ATTNUserIdentity!

  override func setUp() {
    super.setUp()
    urlProvider = ATTNEventURLProvider()
    userIdentity = ATTNTestEventUtils.buildUserIdentity()
  }

  override func tearDown() {
    urlProvider = nil
    userIdentity = nil
    super.tearDown()
  }

  // MARK: - buildNewEventEndpointUrl Tests

  func testBuildNewEventEndpointUrl_validRequest_returnsURL() {
    let eventRequest = ATTNEventRequest(metadata: [:], eventNameAbbreviation: "c")

    let url = urlProvider.buildNewEventEndpointUrl(
      for: eventRequest,
      userIdentity: userIdentity,
      domain: "test.attentivemobile.com"
    )

    XCTAssertNotNil(url)
  }

  func testBuildNewEventEndpointUrl_hasCorrectScheme() {
    let eventRequest = ATTNEventRequest(metadata: [:], eventNameAbbreviation: "c")

    let url = urlProvider.buildNewEventEndpointUrl(
      for: eventRequest,
      userIdentity: userIdentity,
      domain: "test.attentivemobile.com"
    )

    XCTAssertEqual(url?.scheme, "https")
  }

  func testBuildNewEventEndpointUrl_hasCorrectHost() {
    let eventRequest = ATTNEventRequest(metadata: [:], eventNameAbbreviation: "c")

    let url = urlProvider.buildNewEventEndpointUrl(
      for: eventRequest,
      userIdentity: userIdentity,
      domain: "test.attentivemobile.com"
    )

    XCTAssertEqual(url?.host, "events.attentivemobile.com")
  }

  func testBuildNewEventEndpointUrl_hasCorrectPath() {
    let eventRequest = ATTNEventRequest(metadata: [:], eventNameAbbreviation: "c")

    let url = urlProvider.buildNewEventEndpointUrl(
      for: eventRequest,
      userIdentity: userIdentity,
      domain: "test.attentivemobile.com"
    )

    XCTAssertEqual(url?.path, "/mobile")
  }

  func testBuildNewEventEndpointUrl_includesVisitorIdInQueryParams() {
    let eventRequest = ATTNEventRequest(metadata: [:], eventNameAbbreviation: "c")

    let url = urlProvider.buildNewEventEndpointUrl(
      for: eventRequest,
      userIdentity: userIdentity,
      domain: "test.attentivemobile.com"
    )

    XCTAssertNotNil(url)
    let queryItems = ATTNTestEventUtils.getQueryItemsFromUrl(url: url!)
    XCTAssertEqual(queryItems["u"], userIdentity.visitorId)
  }

  func testBuildNewEventEndpointUrl_includesDomainInQueryParams() {
    let domain = "test.attentivemobile.com"
    let eventRequest = ATTNEventRequest(metadata: [:], eventNameAbbreviation: "c")

    let url = urlProvider.buildNewEventEndpointUrl(
      for: eventRequest,
      userIdentity: userIdentity,
      domain: domain
    )

    XCTAssertNotNil(url)
    let queryItems = ATTNTestEventUtils.getQueryItemsFromUrl(url: url!)
    XCTAssertEqual(queryItems["c"], domain)
  }

  func testBuildNewEventEndpointUrl_includesEventTypeInQueryParams() {
    let eventRequest = ATTNEventRequest(metadata: [:], eventNameAbbreviation: "c")

    let url = urlProvider.buildNewEventEndpointUrl(
      for: eventRequest,
      userIdentity: userIdentity,
      domain: "test.attentivemobile.com"
    )

    XCTAssertNotNil(url)
    let queryItems = ATTNTestEventUtils.getQueryItemsFromUrl(url: url!)
    XCTAssertEqual(queryItems["t"], "c")
  }

  func testBuildNewEventEndpointUrl_includesMetadataInQueryParams() {
    let metadata = ["customKey": "customValue"]
    let eventRequest = ATTNEventRequest(metadata: metadata, eventNameAbbreviation: "c")

    let url = urlProvider.buildNewEventEndpointUrl(
      for: eventRequest,
      userIdentity: userIdentity,
      domain: "test.attentivemobile.com"
    )

    XCTAssertNotNil(url)
    let queryItems = ATTNTestEventUtils.getQueryItemsFromUrl(url: url!)

    // Metadata should be JSON-encoded in the "m" parameter
    XCTAssertNotNil(queryItems["m"])
  }

  func testBuildNewEventEndpointUrl_withDeeplink_includesDeeplinkInQueryParams() {
    let eventRequest = ATTNEventRequest(metadata: [:], eventNameAbbreviation: "c")
    eventRequest.deeplink = "https://myapp.com/product/123"

    let url = urlProvider.buildNewEventEndpointUrl(
      for: eventRequest,
      userIdentity: userIdentity,
      domain: "test.attentivemobile.com"
    )

    XCTAssertNotNil(url)
    let queryItems = ATTNTestEventUtils.getQueryItemsFromUrl(url: url!)
    XCTAssertEqual(queryItems["pd"], "https://myapp.com/product/123")
  }

  func testBuildNewEventEndpointUrl_withoutDeeplink_doesNotIncludeDeeplinkParam() {
    let eventRequest = ATTNEventRequest(metadata: [:], eventNameAbbreviation: "c")

    let url = urlProvider.buildNewEventEndpointUrl(
      for: eventRequest,
      userIdentity: userIdentity,
      domain: "test.attentivemobile.com"
    )

    XCTAssertNotNil(url)
    let queryItems = ATTNTestEventUtils.getQueryItemsFromUrl(url: url!)
    XCTAssertNil(queryItems["pd"])
  }

  func testBuildNewEventEndpointUrl_addToCartEvent_correctEventType() {
    let eventRequest = ATTNEventRequest(
      metadata: [:],
      eventNameAbbreviation: ATTNEventTypes.addToCart
    )

    let url = urlProvider.buildNewEventEndpointUrl(
      for: eventRequest,
      userIdentity: userIdentity,
      domain: "test.attentivemobile.com"
    )

    XCTAssertNotNil(url)
    let queryItems = ATTNTestEventUtils.getQueryItemsFromUrl(url: url!)
    XCTAssertEqual(queryItems["t"], ATTNEventTypes.addToCart)
  }

  func testBuildNewEventEndpointUrl_productViewEvent_correctEventType() {
    let eventRequest = ATTNEventRequest(
      metadata: [:],
      eventNameAbbreviation: ATTNEventTypes.productView
    )

    let url = urlProvider.buildNewEventEndpointUrl(
      for: eventRequest,
      userIdentity: userIdentity,
      domain: "test.attentivemobile.com"
    )

    XCTAssertNotNil(url)
    let queryItems = ATTNTestEventUtils.getQueryItemsFromUrl(url: url!)
    XCTAssertEqual(queryItems["t"], ATTNEventTypes.productView)
  }

  func testBuildNewEventEndpointUrl_purchaseEvent_correctEventType() {
    let eventRequest = ATTNEventRequest(
      metadata: [:],
      eventNameAbbreviation: ATTNEventTypes.purchase
    )

    let url = urlProvider.buildNewEventEndpointUrl(
      for: eventRequest,
      userIdentity: userIdentity,
      domain: "test.attentivemobile.com"
    )

    XCTAssertNotNil(url)
    let queryItems = ATTNTestEventUtils.getQueryItemsFromUrl(url: url!)
    XCTAssertEqual(queryItems["t"], ATTNEventTypes.purchase)
  }

  func testBuildNewEventEndpointUrl_customEvent_correctEventType() {
    let eventRequest = ATTNEventRequest(
      metadata: [:],
      eventNameAbbreviation: ATTNEventTypes.customEvent
    )

    let url = urlProvider.buildNewEventEndpointUrl(
      for: eventRequest,
      userIdentity: userIdentity,
      domain: "test.attentivemobile.com"
    )

    XCTAssertNotNil(url)
    let queryItems = ATTNTestEventUtils.getQueryItemsFromUrl(url: url!)
    XCTAssertEqual(queryItems["t"], ATTNEventTypes.customEvent)
  }

  func testBuildNewEventEndpointUrl_includesStandardQueryParams() {
    let eventRequest = ATTNEventRequest(metadata: [:], eventNameAbbreviation: "c")

    let url = urlProvider.buildNewEventEndpointUrl(
      for: eventRequest,
      userIdentity: userIdentity,
      domain: "test.attentivemobile.com"
    )

    XCTAssertNotNil(url)
    let queryItems = ATTNTestEventUtils.getQueryItemsFromUrl(url: url!)

    // Check for standard query params that should be present
    XCTAssertNotNil(queryItems["u"]) // visitor ID
    XCTAssertNotNil(queryItems["c"]) // domain
    XCTAssertNotNil(queryItems["t"]) // event type
    XCTAssertNotNil(queryItems["m"]) // metadata
  }

  func testBuildNewEventEndpointUrl_userIdentityWithIdentifiers_includesIdentifiersInMetadata() {
    let identity = ATTNUserIdentity(identifiers: [
      ATTNIdentifierType.email: "test@example.com",
      ATTNIdentifierType.phone: "+14155551234"
    ])
    let eventRequest = ATTNEventRequest(metadata: [:], eventNameAbbreviation: "c")

    let url = urlProvider.buildNewEventEndpointUrl(
      for: eventRequest,
      userIdentity: identity,
      domain: "test.attentivemobile.com"
    )

    XCTAssertNotNil(url)
    let queryItems = ATTNTestEventUtils.getQueryItemsFromUrl(url: url!)
    let metadata = ATTNTestEventUtils.getMetadataFromUrl(url: url!)

    XCTAssertNotNil(metadata)
    // Verify that user identifiers are included in metadata
    XCTAssertNotNil(metadata?["email"])
    XCTAssertNotNil(metadata?["phone"])
  }
}
