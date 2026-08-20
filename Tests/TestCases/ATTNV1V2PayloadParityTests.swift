//
//  ATTNV1V2PayloadParityTests.swift
//  attentive-ios-sdk Tests
//
//  Parity tests for MSDK-472: flipping `ATTNSDK.useV2Endpoint` to `true` must be
//  invisible to customers. The two paths have different wire shapes by design
//  (v1 `/e` carries everything in the query string; v2 `/mobile` posts a JSON
//  body as `d=<json>`), so "byte-diff parity" here means: for the same input
//  event, every semantic value extracted from both wire formats is
//  byte-for-byte identical — product fields, order/cart fields, custom
//  properties, the `pd` deeplink param, and the shared base query params
//  (visitor ID `u`, external vendor ids `evs`, domain `c`, event abbreviation
//  `t`).
//
//  Both paths are driven through the real `ATTNSDK.send(event:)` +
//  `ATTNAPI` with a mocked URLSession, from a single SDK instance, so the
//  captured requests reflect exactly what each endpoint would receive in
//  production for the same user.
//

import XCTest
@testable import ATTNSDKFramework

final class ATTNV1V2PayloadParityTests: XCTestCase {
    private let testDomain = "test.attentivemobile.com"

    private var sdk: ATTNSDK!
    private var sessionMock: NSURLSessionMock!

    override func setUp() {
        super.setUp()
        sessionMock = NSURLSessionMock()
        let api = ATTNAPI(domain: testDomain, urlSession: sessionMock)
        sdk = ATTNSDK(api: api)
    }

    override func tearDown() {
        sdk = nil
        sessionMock = nil
        super.tearDown()
    }

    // MARK: - Capture helpers

    /// Sends `event` on the requested path and returns the captured requests.
    private func capture(_ event: ATTNEvent, v2: Bool) -> [URLRequest] {
        sessionMock.requests.removeAll()
        sessionMock.urlCalls.removeAll()
        sdk._useV2Endpoint = v2
        sdk.send(event: event)
        return sessionMock.requests
    }

    private struct V1Request {
        let queryItems: [String: String]
        let metadata: [String: Any]
    }

    private struct V2Request {
        let queryItems: [String: String]
        let payload: [String: Any]

        var eventMetadata: [String: Any]? { payload["eventMetadata"] as? [String: Any] }
    }

    /// Parses a captured `/e` request: query params + the `m` metadata JSON.
    private func parseV1(_ request: URLRequest, file: StaticString = #filePath, line: UInt = #line) -> V1Request? {
        guard let url = request.url, url.path == "/e" else {
            XCTFail("Expected request to /e, got \(request.url?.absoluteString ?? "nil")", file: file, line: line)
            return nil
        }
        let queryItems = ATTNTestEventUtils.getQueryItemsFromUrl(url: url)
        guard let metadata = ATTNTestEventUtils.getMetadataFromUrl(url: url) else {
            XCTFail("v1 `m` param is missing or not valid JSON: \(url.absoluteString)", file: file, line: line)
            return nil
        }
        return V1Request(queryItems: queryItems, metadata: metadata)
    }

    /// Parses a captured `/mobile` request: query params + the `d=<json>` body.
    private func parseV2(_ request: URLRequest, file: StaticString = #filePath, line: UInt = #line) -> V2Request? {
        guard let url = request.url, url.path == "/mobile" else {
            XCTFail("Expected request to /mobile, got \(request.url?.absoluteString ?? "nil")", file: file, line: line)
            return nil
        }
        guard let bodyData = request.httpBody, let body = String(data: bodyData, encoding: .utf8) else {
            XCTFail("/mobile request has no UTF-8 body", file: file, line: line)
            return nil
        }
        var components = URLComponents()
        components.percentEncodedQuery = body
        let fields = components.queryItems ?? []
        guard fields.count == 1, fields.first?.name == "d", let json = fields.first?.value else {
            XCTFail("/mobile body must be a single `d` form field; got \(fields.map(\.name))", file: file, line: line)
            return nil
        }
        guard let jsonData = json.data(using: .utf8),
              let payload = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
            XCTFail("/mobile `d` value is not valid JSON: \(json)", file: file, line: line)
            return nil
        }
        return V2Request(queryItems: ATTNTestEventUtils.getQueryItemsFromUrl(url: url), payload: payload)
    }

    /// Convenience: send on both paths and parse a single request from each.
    private func captureSingleParity(_ makeEvent: () -> ATTNEvent, file: StaticString = #filePath, line: UInt = #line) -> (V1Request, V2Request)? {
        let v1Requests = capture(makeEvent(), v2: false)
        XCTAssertEqual(v1Requests.count, 1, "Expected exactly one v1 request", file: file, line: line)
        let v2Requests = capture(makeEvent(), v2: true)
        XCTAssertEqual(v2Requests.count, 1, "Expected exactly one v2 request", file: file, line: line)
        guard let first1 = v1Requests.first, let first2 = v2Requests.first,
              let v1 = parseV1(first1, file: file, line: line),
              let v2 = parseV2(first2, file: file, line: line) else { return nil }
        return (v1, v2)
    }

    // MARK: - Byte-level assertion helpers

    /// Swift `String ==` uses Unicode canonical equivalence; parity here is
    /// byte-for-byte, so compare the UTF-8 encodings directly.
    private func assertByteEqual(_ lhs: String?, _ rhs: String?, _ label: String, file: StaticString = #filePath, line: UInt = #line) {
        guard let lhs, let rhs else {
            XCTAssertEqual(lhs, rhs, "\(label): one side is nil", file: file, line: line)
            return
        }
        XCTAssertEqual(Array(lhs.utf8), Array(rhs.utf8), "\(label): '\(lhs)' vs '\(rhs)' differ at byte level", file: file, line: line)
    }

    /// Base query params both endpoints share must be identical — this also
    /// locks visitor-ID (`u`) and external-vendor-ID (`evs`) parity across paths.
    private func assertBaseQueryParity(_ v1: [String: String], _ v2: [String: String], file: StaticString = #filePath, line: UInt = #line) {
        for key in ["tag", "v", "c", "lt", "u", "evs", "t", "pd"] {
            assertByteEqual(v1[key], v2[key], "query param `\(key)`", file: file, line: line)
        }
        XCTAssertEqual(v1["u"], sdk.userIdentity.visitorId, "v1 `u` must be the SDK visitor ID", file: file, line: line)
    }

    /// Compares a v1 item-metadata dictionary against a v2 product dictionary.
    private func assertProductParity(v1 metadata: [String: Any], v2 product: [String: Any], file: StaticString = #filePath, line: UInt = #line) {
        assertByteEqual(metadata["productId"] as? String, product["productId"] as? String, "productId", file: file, line: line)
        assertByteEqual(metadata["subProductId"] as? String, product["variantId"] as? String, "variantId/subProductId", file: file, line: line)
        assertByteEqual(metadata["name"] as? String, product["name"] as? String, "product name", file: file, line: line)
        assertByteEqual(metadata["price"] as? String, product["price"] as? String, "price", file: file, line: line)
        assertByteEqual(metadata["image"] as? String, product["imageUrl"] as? String, "image/imageUrl", file: file, line: line)

        // v1 sends a single category string; v2 sends a one-element array.
        let v2Categories = product["categories"] as? [String]
        assertByteEqual(metadata["category"] as? String, v2Categories?.first, "category", file: file, line: line)
        XCTAssertLessThanOrEqual(v2Categories?.count ?? 0, 1, "v2 categories should mirror the single legacy category", file: file, line: line)

        // v1 sends quantity as a string; v2 as an integer.
        XCTAssertEqual(Int(metadata["quantity"] as? String ?? ""), product["quantity"] as? Int, "quantity", file: file, line: line)
    }

    // MARK: - ProductView

    func testProductView_baseQueryParamsAndVisitorId_matchAcrossPaths() {
        guard let (v1, v2) = captureSingleParity({ ATTNTestEventUtils.buildProductView() }) else { return }
        XCTAssertEqual(v1.queryItems["t"], "d")
        assertBaseQueryParity(v1.queryItems, v2.queryItems)
        assertByteEqual(v2.payload["visitorId"] as? String, sdk.userIdentity.visitorId, "v2 body visitorId")
    }

    func testProductView_productFields_matchAcrossPaths() {
        guard let (v1, v2) = captureSingleParity({ ATTNTestEventUtils.buildProductView() }) else { return }
        guard let product = v2.eventMetadata?["product"] as? [String: Any] else {
            XCTFail("v2 ProductView payload has no eventMetadata.product")
            return
        }
        assertProductParity(v1: v1.metadata, v2: product)
        assertByteEqual(v1.metadata["currency"] as? String, v2.eventMetadata?["currency"] as? String, "currency")
    }

    func testProductView_deeplink_matchesAcrossPaths() {
        guard let (v1, v2) = captureSingleParity({
            let event = ATTNTestEventUtils.buildProductView()
            event.deeplink = "myapp://product/123?ref=a&b=c"
            return event
        }) else { return }
        assertByteEqual(v1.queryItems["pd"], "myapp://product/123?ref=a&b=c", "v1 pd")
        assertByteEqual(v1.queryItems["pd"], v2.queryItems["pd"], "pd across paths")
    }

    // MARK: - AddToCart

    func testAddToCart_productFields_matchAcrossPaths() {
        guard let (v1, v2) = captureSingleParity({ ATTNTestEventUtils.buildAddToCart() }) else { return }
        XCTAssertEqual(v1.queryItems["t"], "c")
        assertBaseQueryParity(v1.queryItems, v2.queryItems)
        guard let product = v2.eventMetadata?["product"] as? [String: Any] else {
            XCTFail("v2 AddToCart payload has no eventMetadata.product")
            return
        }
        assertProductParity(v1: v1.metadata, v2: product)
        assertByteEqual(v1.metadata["currency"] as? String, v2.eventMetadata?["currency"] as? String, "currency")
    }

    func testAddToCart_deeplink_matchesAcrossPaths() {
        guard let (v1, v2) = captureSingleParity({
            let event = ATTNTestEventUtils.buildAddToCart()
            event.deeplink = "myapp://cart"
            return event
        }) else { return }
        assertByteEqual(v1.queryItems["pd"], v2.queryItems["pd"], "pd across paths")
    }

    // MARK: - Purchase

    /// v1 emits one `p` request per item plus one `oc` (OrderConfirmed);
    /// v2 emits a single `Purchase` with a products array. Parity target is the
    /// `p` request(s) against the v2 payload.
    private func purchaseParity(_ makeEvent: () -> ATTNPurchaseEvent, file: StaticString = #filePath, line: UInt = #line) -> (v1Purchases: [V1Request], v1OrderConfirmed: V1Request, v2: V2Request)? {
        let event = makeEvent()
        let itemCount = event.items.count

        let v1Requests = capture(makeEvent(), v2: false)
        XCTAssertEqual(v1Requests.count, itemCount + 1, "v1 purchase should emit one `p` per item plus one `oc`", file: file, line: line)
        let parsed = v1Requests.compactMap { parseV1($0, file: file, line: line) }
        let purchases = parsed.filter { $0.queryItems["t"] == "p" }
        let orderConfirmed = parsed.filter { $0.queryItems["t"] == "oc" }
        XCTAssertEqual(purchases.count, itemCount, file: file, line: line)
        XCTAssertEqual(orderConfirmed.count, 1, file: file, line: line)

        let v2Requests = capture(makeEvent(), v2: true)
        XCTAssertEqual(v2Requests.count, 1, "v2 purchase should emit a single request", file: file, line: line)
        guard let oc = orderConfirmed.first,
              let firstV2 = v2Requests.first,
              let v2 = parseV2(firstV2, file: file, line: line) else { return nil }
        return (purchases, oc, v2)
    }

    func testPurchase_singleItem_orderAndCartFields_matchAcrossPaths() {
        guard let (v1Purchases, _, v2) = purchaseParity({ ATTNTestEventUtils.buildPurchase() }) else { return }
        guard let v1 = v1Purchases.first, let metadata = v2.eventMetadata else { return }

        assertBaseQueryParity(v1.queryItems, v2.queryItems)

        assertByteEqual(v1.metadata["orderId"] as? String, metadata["orderId"] as? String, "orderId")
        assertByteEqual(v1.metadata["currency"] as? String, metadata["currency"] as? String, "currency")

        let v2Cart = metadata["cart"] as? [String: Any]
        assertByteEqual(v1.metadata["cartId"] as? String, v2Cart?["cartId"] as? String, "cartId")
        assertByteEqual(v1.metadata["cartCoupon"] as? String, v2Cart?["cartCoupon"] as? String, "cartCoupon")
        assertByteEqual(v1.metadata["cartTotal"] as? String, v2Cart?["cartTotal"] as? String, "cartTotal")
        // The v2 orderTotal must match the legacy cartTotal formula (MSDK-442
        // decision: sum of item prices, quantity-agnostic, 2 fraction digits).
        assertByteEqual(v1.metadata["cartTotal"] as? String, metadata["orderTotal"] as? String, "orderTotal vs legacy cartTotal")

        guard let products = metadata["products"] as? [[String: Any]], products.count == 1 else {
            XCTFail("v2 Purchase payload should carry exactly one product")
            return
        }
        assertProductParity(v1: v1.metadata, v2: products[0])
    }

    func testPurchase_multiItem_productsAndTotals_matchAcrossPaths() {
        guard let (v1Purchases, v1OrderConfirmed, v2) = purchaseParity({ ATTNTestEventUtils.buildPurchaseWithTwoItems() }) else { return }
        guard let metadata = v2.eventMetadata else { return }

        guard let products = metadata["products"] as? [[String: Any]], products.count == v1Purchases.count else {
            XCTFail("v2 products count must match the number of v1 `p` requests")
            return
        }
        // v1 emits requests in item order; v2 products preserve the same order.
        for (v1, product) in zip(v1Purchases, products) {
            assertProductParity(v1: v1.metadata, v2: product)
        }

        // cartTotal is shared across every v1 request and must be quantity-agnostic
        // (sum of unit prices) on both paths: 15.99 + 20.00 = 35.99.
        let expectedTotal = "35.99"
        let v2Cart = metadata["cart"] as? [String: Any]
        for v1 in v1Purchases {
            assertByteEqual(v1.metadata["cartTotal"] as? String, expectedTotal, "v1 cartTotal")
        }
        assertByteEqual(v1OrderConfirmed.metadata["cartTotal"] as? String, expectedTotal, "v1 oc cartTotal")
        assertByteEqual(v2Cart?["cartTotal"] as? String, expectedTotal, "v2 cart.cartTotal")
        assertByteEqual(metadata["orderTotal"] as? String, expectedTotal, "v2 orderTotal")
    }

    /// Regression guard for price formatting: the legacy path formats prices with
    /// the POSIX 2-fraction-digit formatter ("10" → "10.00"). The v2 conversion
    /// must produce the identical string or historical numbers shift when hosts
    /// flip `useV2Endpoint`.
    func testPurchase_integralPrice_priceStringsMatchAcrossPaths() {
        let makeEvent: () -> ATTNPurchaseEvent = {
            let price = ATTNPrice(price: NSDecimalNumber(string: "10"), currency: "USD")
            let item = ATTNItem(productId: "1", productVariantId: "1-v", price: price)
            item.name = "Ten Dollar Item"
            return ATTNPurchaseEvent(items: [item], order: ATTNOrder(orderId: "o-10"))
        }
        guard let (v1Purchases, _, v2) = purchaseParity(makeEvent) else { return }
        guard let v1 = v1Purchases.first, let metadata = v2.eventMetadata,
              let products = metadata["products"] as? [[String: Any]] else { return }

        assertByteEqual(v1.metadata["price"] as? String, "10.00", "v1 price formatting")
        assertByteEqual(v1.metadata["price"] as? String, products.first?["price"] as? String, "price across paths")
        assertByteEqual(v1.metadata["cartTotal"] as? String, metadata["orderTotal"] as? String, "orderTotal across paths")
    }

    // MARK: - Custom events

    func testCustomEvent_typeAndProperties_matchAcrossPaths() {
        guard let (v1, v2) = captureSingleParity({ ATTNTestEventUtils.buildCustomEvent() }) else { return }
        XCTAssertEqual(v1.queryItems["t"], "ce")
        assertBaseQueryParity(v1.queryItems, v2.queryItems)

        guard let metadata = v2.eventMetadata else {
            XCTFail("v2 custom event payload has no eventMetadata")
            return
        }
        assertByteEqual(v1.metadata["type"] as? String, metadata["type"] as? String, "custom event type")

        // v1 nests properties as a JSON string inside `m`; v2 carries a dictionary.
        guard let v1PropertiesJson = v1.metadata["properties"] as? String,
              let v1Properties = try? JSONSerialization.jsonObject(with: Data(v1PropertiesJson.utf8)) as? [String: String] else {
            XCTFail("v1 custom event properties are not a JSON string")
            return
        }
        let v2Properties = metadata["customProperties"] as? [String: String]
        XCTAssertEqual(v1Properties.count, v2Properties?.count, "property count")
        for (key, value) in v1Properties {
            assertByteEqual(value, v2Properties?[key], "custom property `\(key)`")
        }
    }

    // MARK: - Special characters (MSDK-441 root cause: `& = + ' "` and emoji)

    private let specialCharacterSamples = [
        "Grab & Go Snacks",
        "Buy 1 = Get 1",
        "1 + 1 Free",
        "It's a \"Deal\"",
        "Emoji 🛒 Sneaker 👟 & Co. – café crème"
    ]

    func testProductView_specialCharacterNames_roundTripIdenticallyOnBothPaths() {
        for name in specialCharacterSamples {
            guard let (v1, v2) = captureSingleParity({
                let item = ATTNTestEventUtils.buildItem()
                item.name = name
                return ATTNProductViewEvent(items: [item])
            }) else { continue }
            let product = v2.eventMetadata?["product"] as? [String: Any]
            // Each path must round-trip the exact input bytes...
            assertByteEqual(v1.metadata["name"] as? String, name, "v1 name round-trip for '\(name)'")
            assertByteEqual(product?["name"] as? String, name, "v2 name round-trip for '\(name)'")
            // ...and therefore match each other.
            assertByteEqual(v1.metadata["name"] as? String, product?["name"] as? String, "name across paths for '\(name)'")
        }
    }

    func testPurchase_specialCharacterNames_roundTripIdenticallyOnBothPaths() {
        for name in specialCharacterSamples {
            let makeEvent: () -> ATTNPurchaseEvent = {
                let item = ATTNTestEventUtils.buildItem()
                item.name = name
                return ATTNPurchaseEvent(items: [item], order: ATTNOrder(orderId: "778899"))
            }
            guard let (v1Purchases, _, v2) = purchaseParity(makeEvent) else { continue }
            let products = v2.eventMetadata?["products"] as? [[String: Any]]
            assertByteEqual(v1Purchases.first?.metadata["name"] as? String, name, "v1 purchase name round-trip for '\(name)'")
            assertByteEqual(products?.first?["name"] as? String, name, "v2 purchase name round-trip for '\(name)'")
        }
    }

    func testCustomEvent_specialCharacterPropertyValues_roundTripIdenticallyOnBothPaths() {
        for value in specialCharacterSamples {
            guard let event = ATTNCustomEvent(type: "Parity Test", properties: ["sample": value]) else {
                XCTFail("Failed to build custom event for value '\(value)'")
                continue
            }
            guard let (v1, v2) = captureSingleParity({ event }) else { continue }

            guard let v1PropertiesJson = v1.metadata["properties"] as? String,
                  let v1Properties = try? JSONSerialization.jsonObject(with: Data(v1PropertiesJson.utf8)) as? [String: String] else {
                XCTFail("v1 custom event properties are not a JSON string for value '\(value)'")
                continue
            }
            let v2Properties = v2.eventMetadata?["customProperties"] as? [String: String]
            assertByteEqual(v1Properties["sample"], value, "v1 property round-trip for '\(value)'")
            assertByteEqual(v2Properties?["sample"], value, "v2 property round-trip for '\(value)'")
        }
    }

    func testProductView_specialCharacterDeeplink_roundTripsIdenticallyOnBothPaths() {
        let deeplink = "myapp://search?q=grab+%26+go&sort=price"
        guard let (v1, v2) = captureSingleParity({
            let event = ATTNTestEventUtils.buildProductView()
            event.deeplink = deeplink
            return event
        }) else { return }
        assertByteEqual(v1.queryItems["pd"], deeplink, "v1 pd round-trip")
        assertByteEqual(v2.queryItems["pd"], deeplink, "v2 pd round-trip")
    }
}
