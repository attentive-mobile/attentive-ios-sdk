//
//  ATTNAPITests.swift
//  attentive-ios-sdk Tests
//
//  Created by Vladimir - Work on 2024-06-04.
//

import XCTest
@testable import ATTNSDKFramework

final class ATTNAPITests: XCTestCase {
    let testDomain = "some-domain"

    func testURLSession_verifySessionHasUserAgent() {
        let userAgentBuilderMock = ATTNUserAgentBuilderMock()

        let api = ATTNAPI(domain: "somedomain", urlSession: URLSession.build(withUserAgent: userAgentBuilderMock.buildUserAgent()))

        let additionalHeaders = api.urlSession.configuration.httpAdditionalHeaders
        XCTAssertEqual(1, additionalHeaders?.count)
        XCTAssertEqual("User-Agent", additionalHeaders?.keys.first)
        XCTAssertEqual("fakeUserAgent", additionalHeaders?["User-Agent"] as? String)
    }

    func testSendUserIdentity_validIdentifiers_callsEndpoints() {
        // Arrange
        let sessionMock = NSURLSessionMock()
        let api = ATTNAPI(domain: testDomain, urlSession: sessionMock)

        let userIdentity = ATTNTestEventUtils.buildUserIdentity()

        // Act
        api.send(userIdentity: userIdentity)

        // Assert
        XCTAssertTrue(sessionMock.didCallEventsApi)
    }

    func testSendEvent_validEvent_callsEventEndpoint() {
        // Arrange
        let sessionMock = NSURLSessionMock()
        let api = ATTNAPI(domain: testDomain, urlSession: sessionMock)
        let purchase = ATTNTestEventUtils.buildPurchase()
        let userIdentity = ATTNTestEventUtils.buildUserIdentity()

        // Act
        api.send(event: purchase, userIdentity: userIdentity)

        // Assert
        XCTAssertTrue(sessionMock.didCallEventsApi)
        XCTAssertEqual(2, sessionMock.urlCalls.count)
        let eventsUrl = sessionMock.urlCalls[0]
        let queryItems = ATTNTestEventUtils.getQueryItemsFromUrl(url: eventsUrl)
        XCTAssertEqual("mobile-app", queryItems["v"])
        XCTAssertEqual("p", queryItems["t"])
    }

    func testSendEvent_validPurchaseEvent_urlContainsExpectedPurchaseMetadata() {
        // Arrange
        let sessionMock = NSURLSessionMock()
        let api = ATTNAPI(domain: testDomain, urlSession: sessionMock)
        let purchase = ATTNTestEventUtils.buildPurchase()
        let userIdentity = ATTNTestEventUtils.buildUserIdentity()

        // Act
        api.send(event: purchase, userIdentity: userIdentity)

        // Assert
        XCTAssertTrue(sessionMock.didCallEventsApi)
        XCTAssertEqual(2, sessionMock.urlCalls.count)
        let purchaseUrl = sessionMock.urlCalls[0]
        let queryItems = ATTNTestEventUtils.getQueryItemsFromUrl(url: purchaseUrl)
        let queryItemsString = queryItems["m"]
        let metadata = try! JSONSerialization.jsonObject(with: queryItemsString!.data(using: .utf8)!, options: []) as! [String: Any]

        XCTAssertEqual(purchase.items[0].productId, metadata["productId"] as? String)
        XCTAssertEqual(purchase.items[0].productVariantId, metadata["subProductId"] as? String)
        XCTAssertEqual(purchase.items[0].price.amount, NSDecimalNumber(string: metadata["price"] as? String ?? ""))
        XCTAssertEqual(purchase.items[0].price.currency, metadata["currency"] as? String)
        XCTAssertEqual(purchase.items[0].category, metadata["category"] as? String)
        XCTAssertEqual(purchase.items[0].productImage, metadata["image"] as? String)
        XCTAssertEqual(purchase.items[0].name, metadata["name"] as? String)
        let quantity = String(purchase.items[0].quantity)
        XCTAssertEqual(quantity, metadata["quantity"] as? String)
        XCTAssertEqual(purchase.order.orderId, metadata["orderId"] as? String)
        XCTAssertEqual(purchase.cart?.cartId, metadata["cartId"] as? String)
        XCTAssertEqual(purchase.cart?.cartCoupon, metadata["cartCoupon"] as? String)
    }

    func testSendEvent_validPurchaseEventWithTwoItems_urlContainsExpectedOrderConfirmedMetadata() {
        // Arrange
        let sessionMock = NSURLSessionMock()
        let api = ATTNAPI(domain: testDomain, urlSession: sessionMock)
        let purchase = ATTNTestEventUtils.buildPurchaseWithTwoItems()
        let userIdentity = ATTNTestEventUtils.buildUserIdentity()

        // Act
        api.send(event: purchase, userIdentity: userIdentity)

        // Assert
        XCTAssertTrue(sessionMock.didCallEventsApi)
        XCTAssertEqual(3, sessionMock.urlCalls.count)
        var orderConfirmedUrl: URL!
        for url in sessionMock.urlCalls {
            if url.absoluteString.contains("t=oc") {
                orderConfirmedUrl = url
            }
        }
        XCTAssertNotNil(orderConfirmedUrl)

        let ocMetadata = ATTNTestEventUtils.getMetadataFromUrl(url: orderConfirmedUrl)!
        let ocMetadataProducts = ocMetadata["products"] as! String
        let products: [[String: String]] = try! JSONSerialization.jsonObject(
            with: ocMetadataProducts.data(using: .utf8)!,
            options: []
        ) as! [[String : String]]
        XCTAssertEqual(2, products.count)

        ATTNTestEventUtils.verifyProductFromItem(item: purchase.items[0], product: products[0])
        ATTNTestEventUtils.verifyProductFromItem(item: purchase.items[1], product: products[1])

        XCTAssertEqual(purchase.order.orderId, ocMetadata["orderId"] as? String)
        XCTAssertEqual("35.99", ocMetadata["cartTotal"] as? String)
        XCTAssertEqual(purchase.items[0].price.currency, ocMetadata["currency"] as? String)
    }

    func testSendEvent_purchaseEventWithTwoItems_threeRequestsAreSent() {
        // Arrange
        let sessionMock = NSURLSessionMock()
        let api = ATTNAPI(domain: testDomain, urlSession: sessionMock)
        let purchase = ATTNTestEventUtils.buildPurchaseWithTwoItems()
        let userIdentity = ATTNTestEventUtils.buildUserIdentity()

        // Act
        api.send(event: purchase, userIdentity: userIdentity)

        // Assert
        XCTAssertTrue(sessionMock.didCallEventsApi)
        XCTAssertEqual(3, sessionMock.urlCalls.count)

        // check the first item was converted to an event call
        let metadata = ATTNTestEventUtils.getMetadataFromUrl(url: sessionMock.urlCalls[0]) as! [String: String]
        XCTAssertEqual(purchase.items[0].productId, metadata["productId"])
        let queryItems = ATTNTestEventUtils.getQueryItemsFromUrl(url: sessionMock.urlCalls[0])
        XCTAssertEqual("p", queryItems["t"])

        // check the second item was converted to an event call
        let metadata2 = ATTNTestEventUtils.getMetadataFromUrl(url: sessionMock.urlCalls[1]) as! [String: String]
        XCTAssertEqual(purchase.items[1].productId, metadata2["productId"])
        let queryItems2 = ATTNTestEventUtils.getQueryItemsFromUrl(url: sessionMock.urlCalls[1])
        XCTAssertEqual("p", queryItems2["t"])

        // check an OrderConfirmed was created
        let metadata3 = ATTNTestEventUtils.getMetadataFromUrl(url: sessionMock.urlCalls[2]) as! [String: String]
        XCTAssertEqual(purchase.order.orderId, metadata3["orderId"])
        let queryItems3 = ATTNTestEventUtils.getQueryItemsFromUrl(url: sessionMock.urlCalls[2])
        XCTAssertEqual("oc", queryItems3["t"])
    }

    func testSendEvent_validAddToCartEvent_urlContainsExpectedMetadata() {
        // Arrange
        let sessionMock = NSURLSessionMock()
        let api = ATTNAPI(domain: testDomain, urlSession: sessionMock)
        let addToCart = ATTNTestEventUtils.buildAddToCart()
        let userIdentity = ATTNTestEventUtils.buildUserIdentity()

        // Act
        api.send(event: addToCart, userIdentity: userIdentity)

        // Assert
        XCTAssertTrue(sessionMock.didCallEventsApi)
        XCTAssertEqual(1, sessionMock.urlCalls.count)
        let addToCartUrl = sessionMock.urlCalls[0]
        let queryItems = ATTNTestEventUtils.getQueryItemsFromUrl(url: addToCartUrl)
        let queryItemsString = queryItems["m"]
        let metadata = try! JSONSerialization.jsonObject(with: queryItemsString!.data(using: .utf8)!, options: []) as! [String: Any]

        XCTAssertEqual("c", queryItems["t"])

        XCTAssertEqual(addToCart.items[0].productId, metadata["productId"] as? String)
        XCTAssertEqual(addToCart.items[0].productVariantId, metadata["subProductId"] as? String)
        XCTAssertEqual(addToCart.items[0].price.amount, NSDecimalNumber(string: metadata["price"] as? String ?? ""))
        XCTAssertEqual(addToCart.items[0].price.currency, metadata["currency"] as? String)
        XCTAssertEqual(addToCart.items[0].category, metadata["category"] as? String)
        XCTAssertEqual(addToCart.items[0].productImage, metadata["image"] as? String)
        XCTAssertEqual(addToCart.items[0].name, metadata["name"] as? String)
        let quantity = String(addToCart.items[0].quantity)
        XCTAssertEqual(quantity, metadata["quantity"] as? String)
    }

    func testSendEvent_validProductViewEvent_urlContainsExpectedMetadata() {
        // Arrange
        let sessionMock = NSURLSessionMock()
        let api = ATTNAPI(domain: testDomain, urlSession: sessionMock)
        let productView = ATTNTestEventUtils.buildProductView()
        let userIdentity = ATTNTestEventUtils.buildUserIdentity()

        // Act
        api.send(event: productView, userIdentity: userIdentity)

        // Assert
        XCTAssertTrue(sessionMock.didCallEventsApi)
        XCTAssertEqual(1, sessionMock.urlCalls.count)
        let url = sessionMock.urlCalls[0]
        let queryItems = ATTNTestEventUtils.getQueryItemsFromUrl(url: url)
        let queryItemsString = queryItems["m"]
        let metadata = try! JSONSerialization.jsonObject(with: queryItemsString!.data(using: .utf8)!, options: []) as! [String: Any]

        XCTAssertEqual("d", queryItems["t"])

        XCTAssertEqual(productView.items[0].productId, metadata["productId"] as? String)
        XCTAssertEqual(productView.items[0].productVariantId, metadata["subProductId"] as? String)
        XCTAssertEqual(productView.items[0].price.amount, NSDecimalNumber(string: metadata["price"] as? String ?? ""))
        XCTAssertEqual(productView.items[0].price.currency, metadata["currency"] as? String)
        XCTAssertEqual(productView.items[0].category, metadata["category"] as? String)
        XCTAssertEqual(productView.items[0].productImage, metadata["image"] as? String)
        XCTAssertEqual(productView.items[0].name, metadata["name"] as? String)
        let quantity = String(productView.items[0].quantity)
        XCTAssertEqual(quantity, metadata["quantity"] as? String)
    }

    func testSendEvent_validInfoEvent_urlContainsExpectedMetadata() {
        // Arrange
        let sessionMock = NSURLSessionMock()
        let api = ATTNAPI(domain: testDomain, urlSession: sessionMock)
        let infoEvent = ATTNTestEventUtils.buildInfoEvent()
        let userIdentity = ATTNTestEventUtils.buildUserIdentity()

        // Act
        api.send(event: infoEvent, userIdentity: userIdentity)

        // Assert
        XCTAssertTrue(sessionMock.didCallEventsApi)
        XCTAssertEqual(1, sessionMock.urlCalls.count)
        let url = sessionMock.urlCalls[0]
        let queryItems = ATTNTestEventUtils.getQueryItemsFromUrl(url: url)

        XCTAssertEqual("i", queryItems["t"])
    }

    func testSendEvent_validCustomEventWithAllProperties_urlContainsExpectedCustomEventMetadata() {
        // Arrange
        let sessionMock = NSURLSessionMock()
        let api = ATTNAPI(domain: testDomain, urlSession: sessionMock)
        let customEvent = ATTNTestEventUtils.buildCustomEvent()
        let userIdentity = ATTNTestEventUtils.buildUserIdentity()

        // Act
        api.send(event: customEvent, userIdentity: userIdentity)

        // Assert
        XCTAssertTrue(sessionMock.didCallEventsApi)
        XCTAssertEqual(1, sessionMock.urlCalls.count)
        var customEventUrl: URL!
        for url in sessionMock.urlCalls {
            if url.absoluteString.contains("t=ce") {
                customEventUrl = url
            }
        }
        XCTAssertNotNil(customEventUrl)

        guard let ceMetadata = ATTNTestEventUtils.getMetadataFromUrl(url: customEventUrl) else {
            XCTFail("Failed to extract metadata from custom event URL")
            return
        }

        guard let actualPropertiesData = (ceMetadata["properties"] as? String)?.data(using: .utf8) else {
            XCTFail("Failed to convert properties data to UTF-8")
            return
        }

        guard let actualProperties = try? JSONSerialization.jsonObject(with: actualPropertiesData, options: []) as? [String: String] else {
            XCTFail("Failed to serialize actual properties data")
            return
        }

        XCTAssertEqual(1, actualProperties.count)

        XCTAssertEqual(customEvent.type, ceMetadata["type"] as! String)
        XCTAssertEqual(customEvent.properties, actualProperties)
    }

    func testSendEvent_validEvent_httpMethodIsPost() {
        // Arrange
        let sessionMock = NSURLSessionMock()
        let api = ATTNAPI(domain: testDomain, urlSession: sessionMock)
        let productView = ATTNTestEventUtils.buildProductView()
        let userIdentity = ATTNTestEventUtils.buildUserIdentity()

        // Act
        api.send(event: productView, userIdentity: userIdentity)

        // Assert
        XCTAssertTrue(sessionMock.didCallEventsApi)
        XCTAssertEqual(1, sessionMock.urlCalls.count)
        let request = sessionMock.requests[0]
        XCTAssertEqual("POST", request.httpMethod?.uppercased())
    }

    func testSendEvent_multipleEventsSent_callsEventsApiForEach() {
        let sessionMock = NSURLSessionMock()
        let api = ATTNAPI(domain: testDomain, urlSession: sessionMock)
        let addToCart1 = ATTNTestEventUtils.buildAddToCart()
        let addToCart2 = ATTNTestEventUtils.buildAddToCart()
        let userIdentity = ATTNTestEventUtils.buildUserIdentity()

        api.send(event: addToCart1, userIdentity: userIdentity)
        XCTAssertTrue(sessionMock.didCallEventsApi)
        XCTAssertEqual(1, sessionMock.urlCalls.count)

        api.send(event: addToCart2, userIdentity: userIdentity)
        XCTAssertTrue(sessionMock.didCallEventsApi)
        XCTAssertEqual(2, sessionMock.urlCalls.count)
    }

    // MARK: - MSDK-517: wire visitor id equals the passed argument

    /// Locks down the primary MSDK-517 invariant at the API boundary: `ATTNAPI.updateUser`
    /// serializes the `visitorId` argument into the `"u"` field of the JSON payload it POSTs
    /// to `/user-update` — without re-reading any live identity reference. Without this
    /// direct-payload test, the SDK-level regression tests all go through `ATTNAPISpy`, which
    /// never touched `userIdentity.visitorId` (pre-fix or post-fix), so they can't observe
    /// whether the real `ATTNAPI` obeys its contract.
    func testUpdateUser_payloadUField_equalsPassedVisitorIdVerbatim() throws {
        let sessionMock = UserUpdateCapturingSessionMock()
        let api = ATTNAPI(domain: testDomain, urlSession: sessionMock)

        let sentVisitorId = "visitor-passed-into-api-\(UUID().uuidString)"
        api.updateUser(
            pushToken: "some-push-token",
            visitorId: sentVisitorId,
            email: "user@example.com",
            phone: "+15551234567",
            operationContext: "clearUser",
            callback: nil
        )

        let request = try XCTUnwrap(sessionMock.lastUserUpdateRequest,
                                    "ATTNAPI.updateUser must POST to /user-update")
        let body = try XCTUnwrap(request.httpBody, "the /user-update request must have a JSON body")
        let payload = try XCTUnwrap(try JSONSerialization.jsonObject(with: body) as? [String: Any])
        XCTAssertEqual(payload["u"] as? String, sentVisitorId,
                       "payload \"u\" must equal the visitorId argument verbatim — no re-read from a live identity reference")
    }

    /// Companion assertion for `testUpdateUser_payloadUField_equalsPassedVisitorIdVerbatim`:
    /// two consecutive calls with different `visitorId` arguments produce two payloads whose
    /// `"u"` fields track the arguments. If `ATTNAPI` ever regressed to reading a shared
    /// identity reference again, both payloads would carry the same (last-read) value.
    func testUpdateUser_payloadUField_tracksEachCallArgumentIndependently() throws {
        let sessionMock = UserUpdateCapturingSessionMock()
        let api = ATTNAPI(domain: testDomain, urlSession: sessionMock)

        api.updateUser(pushToken: "tok", visitorId: "V-first", email: nil, phone: nil, operationContext: "clearUser", callback: nil)
        api.updateUser(pushToken: "tok", visitorId: "V-second", email: nil, phone: nil, operationContext: "clearUser", callback: nil)

        XCTAssertEqual(sessionMock.userUpdateRequests.count, 2)
        let firstBody = try XCTUnwrap(sessionMock.userUpdateRequests[0].httpBody)
        let secondBody = try XCTUnwrap(sessionMock.userUpdateRequests[1].httpBody)
        let firstPayload = try XCTUnwrap(try JSONSerialization.jsonObject(with: firstBody) as? [String: Any])
        let secondPayload = try XCTUnwrap(try JSONSerialization.jsonObject(with: secondBody) as? [String: Any])
        XCTAssertEqual(firstPayload["u"] as? String, "V-first")
        XCTAssertEqual(secondPayload["u"] as? String, "V-second")
    }
}

/// Session mock scoped to the MSDK-517 tests: captures `/user-update` requests without the
/// `NSURLSessionMock` "events endpoint only" fatalError guard.
private final class UserUpdateCapturingSessionMock: URLSession {
    var userUpdateRequests: [URLRequest] = []
    var lastUserUpdateRequest: URLRequest? { userUpdateRequests.last }

    override init() { super.init() }

    override func dataTask(
        with request: URLRequest,
        completionHandler: @escaping (Data?, URLResponse?, Error?) -> Void
    ) -> URLSessionDataTask {
        if request.url?.path.contains("/user-update") == true {
            userUpdateRequests.append(request)
        }
        return NSURLSessionDataTaskMock { _, _, _ in
            let url = request.url ?? URL(string: "https://example.invalid")!
            completionHandler(Data(), HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil), nil)
        }
    }
}
