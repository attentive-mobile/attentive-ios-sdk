//
//  NSURLSessionMock.swift
//  attentive-ios-sdk Tests
//
//  Created by Vladimir - Work on 2024-06-05.
//

import Foundation
@testable import ATTNSDKFramework

class NSURLSessionMock: URLSession {
    var didCallEventsApi = false
    var didCallInboxUnreadCountApi = false
    var didCallInboxMessagesApi = false
    var didCallInboxMarkReadApi = false
    var didCallInboxMarkUnreadApi = false
    var didCallInboxClickedApi = false
    var didCallInboxDeleteApi = false
    var urlCalls: [URL] = []
    var requests: [URLRequest] = []

    /// Override the response returned for the inbox unread count endpoint.
    /// Default: 200 with `{ "unread_count": 5 }`.
    var inboxUnreadCountStatusCode: Int = 200
    var inboxUnreadCountResponseBody: Data = Data("{\"unread_count\": 5}".utf8)
    var inboxUnreadCountError: Error?

    /// Override the response returned for the inbox messages endpoint.
    /// Default: 200 with an empty message list and no next page.
    var inboxMessagesStatusCode: Int = 200
    var inboxMessagesResponseBody: Data = Data("{\"messages\": []}".utf8)
    var inboxMessagesError: Error?

    /// Override the response returned for the mark-read endpoint.
    /// Default: 200 with an empty per-message list and unread_count=0.
    var inboxMarkReadStatusCode: Int = 200
    var inboxMarkReadResponseBody: Data = Data("{\"messages\": [], \"unread_count\": 0}".utf8)
    var inboxMarkReadError: Error?

    /// Override the response returned for the mark-unread endpoint.
    /// Default: 200 with an empty per-message list and unread_count=0.
    var inboxMarkUnreadStatusCode: Int = 200
    var inboxMarkUnreadResponseBody: Data = Data("{\"messages\": [], \"unread_count\": 0}".utf8)
    var inboxMarkUnreadError: Error?

    /// Override the response returned for the inbox click-tracking endpoint.
    /// Default: 204 No Content (per RFC).
    var inboxClickedStatusCode: Int = 204
    var inboxClickedResponseBody: Data = Data()
    var inboxClickedError: Error?

    /// Override the response returned for the inbox delete endpoint.
    /// Default: 200 with an empty body (server contract returns `{ "message_id": "..." }`,
    /// but the SDK does not decode the response).
    var inboxDeleteStatusCode: Int = 200
    var inboxDeleteResponseBody: Data = Data()
    var inboxDeleteError: Error?

    /// When true, every inbox endpoint answers with a plain `URLResponse` instead of an
    /// `HTTPURLResponse`, to exercise the SDK's unexpected-response-type path.
    var inboxReturnsNonHTTPResponse = false

    override init() {
        super.init()
    }

    private func inboxResponse(url: URL, statusCode: Int) -> URLResponse? {
        if inboxReturnsNonHTTPResponse {
            return URLResponse(url: url, mimeType: nil, expectedContentLength: 0, textEncodingName: nil)
        }
        return HTTPURLResponse(url: url, statusCode: statusCode, httpVersion: nil, headerFields: nil)
    }

    override func dataTask(with request: URLRequest, completionHandler: @escaping (Data?, URLResponse?, Error?) -> Void) -> URLSessionDataTask {
        requests.append(request)

        if let url = request.url {
            urlCalls.append(url)

            if url.absoluteString.contains("events.attentivemobile.com") {
                didCallEventsApi = true
                return NSURLSessionDataTaskMock { data, response, error in
                    completionHandler(Data(), HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil), nil)
                }
            }

            // Order matters: check the more specific `/inbox/messages/unread/count` before the
            // `/inbox/messages/read`, `/inbox/messages/unread`, and `/inbox/messages` prefixes
            // so the general checks don't shadow it.
            if url.absoluteString.contains("/inbox/messages/unread/count") {
                didCallInboxUnreadCountApi = true
                let body = inboxUnreadCountResponseBody
                let status = inboxUnreadCountStatusCode
                let error = inboxUnreadCountError
                let response = inboxResponse(url: url, statusCode: status)
                return NSURLSessionDataTaskMock { _, _, _ in
                    completionHandler(body, response, error)
                }
            }

            if url.absoluteString.hasSuffix("/inbox/messages/read") {
                didCallInboxMarkReadApi = true
                let body = inboxMarkReadResponseBody
                let status = inboxMarkReadStatusCode
                let error = inboxMarkReadError
                let response = inboxResponse(url: url, statusCode: status)
                return NSURLSessionDataTaskMock { _, _, _ in
                    completionHandler(body, response, error)
                }
            }

            if url.absoluteString.hasSuffix("/inbox/messages/unread") {
                didCallInboxMarkUnreadApi = true
                let body = inboxMarkUnreadResponseBody
                let status = inboxMarkUnreadStatusCode
                let error = inboxMarkUnreadError
                let response = inboxResponse(url: url, statusCode: status)
                return NSURLSessionDataTaskMock { _, _, _ in
                    completionHandler(body, response, error)
                }
            }

            if url.absoluteString.hasSuffix("/inbox/events/clicked") {
                didCallInboxClickedApi = true
                let body = inboxClickedResponseBody
                let status = inboxClickedStatusCode
                let error = inboxClickedError
                let response = inboxResponse(url: url, statusCode: status)
                return NSURLSessionDataTaskMock { _, _, _ in
                    completionHandler(body, response, error)
                }
            }

            // DELETE targets `/inbox/messages/{id}`. Check the verb so the id-in-path suffix
            // doesn't accidentally shadow the POST list endpoint at `/inbox/messages`.
            if request.httpMethod == "DELETE",
               url.absoluteString.contains("/inbox/messages/") {
                didCallInboxDeleteApi = true
                let body = inboxDeleteResponseBody
                let status = inboxDeleteStatusCode
                let error = inboxDeleteError
                let response = inboxResponse(url: url, statusCode: status)
                return NSURLSessionDataTaskMock { _, _, _ in
                    completionHandler(body, response, error)
                }
            }

            if url.absoluteString.hasSuffix("/inbox/messages") {
                didCallInboxMessagesApi = true
                let body = inboxMessagesResponseBody
                let status = inboxMessagesStatusCode
                let error = inboxMessagesError
                let response = inboxResponse(url: url, statusCode: status)
                return NSURLSessionDataTaskMock { _, _, _ in
                    completionHandler(body, response, error)
                }
            }
        }

        fatalError("Should not get here")
    }
}
