//
//  ATTNRetryingNetworkClientTests.swift
//  attentive-ios-sdk-framework Tests
//
//  Created by Adela Gao on 2025-06-03.
//

import XCTest
@testable import ATTNSDKFramework

/// A URLProtocol subclass that lets us simulate network responses in a deterministic sequence.
final class MockURLProtocol: URLProtocol {
    /// An ordered list of (statusCode, retryAfter, error) tuples to return for each request.
    /// If `retryAfter` is non-nil, the protocol will include a "Retry-After" header.
    static var responseSequence: [(statusCode: Int, retryAfter: TimeInterval?, error: Error?)] = []
    /// How many times a request has been seen so far.
    static var requestCount = 0

    override class func canInit(with request: URLRequest) -> Bool {
        // Intercept all requests.
        return true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        return request
    }

    override func startLoading() {
        // Determine which response to send based on requestCount
        let index = MockURLProtocol.requestCount
        defer { MockURLProtocol.requestCount += 1 }

        guard index < MockURLProtocol.responseSequence.count else {
            // If out of configured range, just send a 200 OK with empty body.
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocolDidFinishLoading(self)
            return
        }

        let entry = MockURLProtocol.responseSequence[index]
        if let err = entry.error {
            // Send a network error
            client?.urlProtocol(self, didFailWithError: err)
        } else {
            var headers: [String: String] = [:]
            if let ra = entry.retryAfter {
                headers["Retry-After"] = String(format: "%.0f", ra)
            }
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: entry.statusCode,
                httpVersion: "HTTP/1.1",
                headerFields: headers
            )!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            // Send zero-length body
            let empty = Data()
            client?.urlProtocol(self, didLoad: empty)
            client?.urlProtocolDidFinishLoading(self)
        }
    }

    override func stopLoading() {
        // Nothing to do.
    }
}


final class ATTNRetryingNetworkClientTests: XCTestCase {
    var client: ATTNRetryingNetworkClient!
    var session: URLSession!

    override func setUp() {
        super.setUp()

        // Use a URLSession configuration that routes through MockURLProtocol.
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        session = URLSession(configuration: config)

        // Use very small delays and no jitter for deterministic timing.
        let retryConfig = ATTNRetryConfiguration(
            initialDelay: 0.01,
            maxRetries: 3,
            jitterRange: 0...0,
            maxCumulativeDelay: 0.5
        )
        client = ATTNRetryingNetworkClient(session: session, config: retryConfig)

        MockURLProtocol.requestCount = 0
        MockURLProtocol.responseSequence = []
    }

    override func tearDown() {
        MockURLProtocol.requestCount = 0
        MockURLProtocol.responseSequence = []
        client = nil
        session = nil
        super.tearDown()
    }

    func testRetriesOnHTTP500_thenSucceeds() {
        // 1st response: 500
        // 2nd response: 500
        // 3rd response: 200 → success
        MockURLProtocol.responseSequence = [
            (statusCode: 500, retryAfter: nil, error: nil),
            (statusCode: 500, retryAfter: nil, error: nil),
            (statusCode: 200, retryAfter: nil, error: nil)
        ]

        let expectation = self.expectation(description: "Callback should be invoked after retries")

        var finalStatusCode: Int?
        client.performRequestWithRetry(URLRequest(url: URL(string: "https://example.com/test")!), to: URL(string: "https://example.com/test")!) { data, sentURL, response, error in
            if let http = response as? HTTPURLResponse {
                finalStatusCode = http.statusCode
            }
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 1.0)
        XCTAssertEqual(finalStatusCode, 200)
        XCTAssertEqual(MockURLProtocol.requestCount, 3,
                                     "Should have sent exactly 3 attempts (2 failures + 1 success)")
    }

    func testRetriesOnURLError_thenSucceeds() {
        // 1st: URLError(.timedOut)
        // 2nd: 200
        let networkErr = URLError(.timedOut)
        MockURLProtocol.responseSequence = [
            (statusCode: 0, retryAfter: nil, error: networkErr),
            (statusCode: 200, retryAfter: nil, error: nil)
        ]

        let expectation = self.expectation(description: "Callback after URLError retry")
        var finalStatusCode: Int?
        client.performRequestWithRetry(URLRequest(url: URL(string: "https://example.com/timeout")!), to: URL(string: "https://example.com/timeout")!) { data, sentURL, response, error in
            finalStatusCode = (response as? HTTPURLResponse)?.statusCode
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 1.0)
        XCTAssertEqual(finalStatusCode, 200)
        XCTAssertEqual(MockURLProtocol.requestCount, 2)
    }

    func testGivesUp_afterMaxRetriesExceeded() {
        // All responses: 500
        MockURLProtocol.responseSequence = [
            (statusCode: 500, retryAfter: nil, error: nil),
            (statusCode: 500, retryAfter: nil, error: nil),
            (statusCode: 500, retryAfter: nil, error: nil),
            (statusCode: 500, retryAfter: nil, error: nil) // won't be reached
        ]

        let expectation = self.expectation(description: "Callback after giving up")
        var attemptsLogged = 0

        client.performRequestWithRetry(URLRequest(url: URL(string: "https://example.com/giveup")!), to: URL(string: "https://example.com/giveup")!) { data, sentURL, response, error in
            if let http = response as? HTTPURLResponse {
                attemptsLogged = http.statusCode // e.g. 500
            }
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 1.0)
        // Should have attempted exactly maxRetries + 1 times in total.
        XCTAssertEqual(MockURLProtocol.requestCount, 4, "3 retries + final give-up response")
    }
}
