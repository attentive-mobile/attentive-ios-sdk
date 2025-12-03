//
//  NSURLSessionMock.swift
//  attentive-ios-sdk Tests
//
//  Created by Vladimir - Work on 2024-06-05.
//

import Foundation
@testable import ATTNSDKFramework

class NSURLSessionMock: URLSession {
    var didCallDtag = false
    var didCallEventsApi = false
    var urlCalls: [URL] = []
    var requests: [URLRequest] = []

    private let TEST_GEO_ADJUSTED_DOMAIN = "some-domain-ca"

    override init() {
        super.init()
    }

    override func dataTask(with request: URLRequest, completionHandler: @escaping (Data?, URLResponse?, Error?) -> Void) -> URLSessionDataTask {
        requests.append(request)

        if let url = request.url {
            urlCalls.append(url)

            if url.absoluteString.contains("cdn.attn.tv") {
                didCallDtag = true
                return NSURLSessionDataTaskMock { data, response, error in
                    completionHandler("a='\(self.TEST_GEO_ADJUSTED_DOMAIN).attn.tv'".data(using: .utf8), HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil), nil)
                }
            }

            if url.absoluteString.contains("events.attentivemobile.com") {
                didCallEventsApi = true
                return NSURLSessionDataTaskMock { data, response, error in
                    completionHandler(Data(), HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil), nil)
                }
            }
        }

        fatalError("Should not get here")
    }
}
