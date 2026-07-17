//
//  ATTNAPI.swift
//  attentive-ios-sdk-framework
//
//  Created by Vladimir - Work on 2024-05-31.
//

import Foundation
import UserNotifications

public typealias ATTNAPICallback = (Data?, URL?, URLResponse?, Error?) -> Void

final class ATTNAPI: ATTNAPIProtocol {
    private var userAgentBuilder: ATTNUserAgentBuilderProtocol = ATTNUserAgentBuilder()
    private var eventUrlProvider: ATTNEventURLProviding = ATTNEventURLProvider()

    private(set) var urlSession: URLSession

    private let retryClient: ATTNRetryingNetworkClient
    private var lastPushTokenSendTime: Date?

    // MARK: ATTNAPIProtocol Properties
    var domain: String

    init(domain: String) {
        self.urlSession = URLSession.build(withUserAgent: userAgentBuilder.buildUserAgent())
        self.domain = domain
        self.retryClient = ATTNRetryingNetworkClient(session: self.urlSession)
    }

    init(domain: String, urlSession: URLSession) {
        self.urlSession = urlSession
        self.domain = domain
        self.retryClient = ATTNRetryingNetworkClient(session: self.urlSession)
    }

    func send(userIdentity: ATTNUserIdentity) {
        send(userIdentity: userIdentity, callback: nil)
    }

    func send(userIdentity: ATTNUserIdentity, callback: ATTNAPICallback?) {
        sendUserIdentityInternal(userIdentity: userIdentity, domain: domain, callback: callback)
    }

    func send(event: ATTNEvent, userIdentity: ATTNUserIdentity) {
        send(event: event, userIdentity: userIdentity, callback: nil)
    }

    func send(event: ATTNEvent, userIdentity: ATTNUserIdentity, callback: ATTNAPICallback?) {
        sendEventInternal(event: event, userIdentity: userIdentity, domain: domain, callback: callback)
    }

    func update(domain newDomain: String) {
        domain = newDomain
    }

    func sendPushToken(_ pushToken: String,
                                         userIdentity: ATTNUserIdentity,
                                         authorizationStatus: UNAuthorizationStatus,
                                         callback: ATTNAPICallback?) {
        // debounce to remove duplicate events; only allow events tracking at most once every 2 seconds
        let now = Date()
        if let last = lastPushTokenSendTime, now.timeIntervalSince(last) < 2 {
            Loggers.event.debug("Skipping duplicate sendPushToken due to debounce.")
            return
        }
        lastPushTokenSendTime = now

        Loggers.network.debug("Sending push token - Visitor ID: \(userIdentity.visitorId, privacy: .public), Push Token: \(pushToken, privacy: .public), Auth Status: \(authorizationStatus.rawValue, privacy: .public)")

        guard let url = eventUrlProvider.buildPushTokenUrl(
            for: userIdentity,
            domain: domain) else {
            Loggers.network.error("Invalid push token URL")
            return
        }

        let evsJson     = userIdentity.buildExternalVendorIdsJson()
        let evsArray    = (try? JSONSerialization.jsonObject(with: Data(evsJson.utf8)))
        as? [[String: String]] ?? []
        let metadataJson = userIdentity.buildMetadataJson()
        let metadata    = (try? JSONSerialization.jsonObject(with: Data(metadataJson.utf8)))
        as? [String: String] ?? [:]

        let authorizationStatusString: String = {
            switch authorizationStatus {
            case .notDetermined: return "notDetermined"
            case .denied:        return "denied"
            case .authorized:    return "authorized"
            case .provisional:   return "provisional"
            case .ephemeral:     return "ephemeral"
            @unknown default:    return "unknown"
            }
        }()

        let payload: [String: Any] = [
            "c": domain,
            "v": "mobile-app-\(ATTNConstants.sdkVersion)",
            "u": userIdentity.visitorId,
            "evs": evsArray,
            "m": metadata,
            "pt": pushToken,
            "st": authorizationStatusString,
            "tp": "apns"
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("1", forHTTPHeaderField: "x-datadog-sampling-priority")
        request.httpBody = try? JSONSerialization.data(withJSONObject: payload)

        Loggers.network.debug("POST /token payload: \(payload, privacy: .public)")

        retryClient.performRequestWithRetry(request, to: url) { data, _, response, error in
            if let error = error {
                Loggers.network.error("Error sending push token: \(error.localizedDescription, privacy: .public)")
            } else if let http = response as? HTTPURLResponse, http.statusCode >= 400 {
                Loggers.network.error("Push-token API returned status \(http.statusCode, privacy: .public)")
            } else {
                Loggers.network.debug("Successfully sent push token")
            }
            callback?(data, url, response, error)
        }
    }

    func sendAppEvents(
            pushToken: String,
            subscriptionStatus: String,
            transport: String,
            events: [[String: Any]],
            userIdentity: ATTNUserIdentity,
            callback: ATTNAPICallback?
        ) {
            Loggers.network.debug("Sending app events - Visitor ID: \(userIdentity.visitorId, privacy: .public), Push Token: \(pushToken, privacy: .public), Subscription Status: \(subscriptionStatus, privacy: .public)")

            let deviceInfo: [String: Any] = [
                "c": domain,
                "v": "mobile-app-\(ATTNConstants.sdkVersion)",
                "u": userIdentity.visitorId,
                "pd": "",
                "m": userIdentity.buildBaseMetadata(),
                "pt": pushToken,
                "st": subscriptionStatus,
                "tp": transport
            ]
            let payload: [String: Any] = [
                "device": deviceInfo,
                "events": events
            ]

            guard let url = URL(string: "https://mobile.attentivemobile.com/mtctrl") else {
                Loggers.network.error("Invalid AppEvents URL")
                return
            }

            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try? JSONSerialization.data(withJSONObject: payload)

            Loggers.network.debug("POST app open events payload: \(payload, privacy: .public)")

            retryClient.performRequestWithRetry(request, to: url) { data, _, response, error in
                if let error = error {
                    Loggers.network.error("Error sending app events: \(error.localizedDescription, privacy: .public)")
                } else if let http = response as? HTTPURLResponse, http.statusCode >= 400 {
                    Loggers.network.error("AppEvents API returned status \(http.statusCode, privacy: .public)")
                } else {
                    Loggers.network.debug("Successfully sent app events")
                }
                callback?(data, url, response, error)
            }
        }

    // MARK: - Opt-In Subscriptions

        func sendOptInMarketingSubscription(
            pushToken: String,
            email: String?,
            phone: String?,
            userIdentity: ATTNUserIdentity,
            callback: ATTNAPICallback?
        ) {
            Loggers.network.debug("Sending opt-in marketing subscription - Visitor ID: \(userIdentity.visitorId, privacy: .public), Push Token: \(pushToken, privacy: .public), Email: \(email ?? "nil", privacy: .public), Phone: \(phone ?? "nil", privacy: .public)")

            let evsJson  = userIdentity.buildExternalVendorIdsJson()
            let evsArray = (try? JSONSerialization.jsonObject(with: Data(evsJson.utf8))) as? [[String: String]] ?? []

            var payload: [String: Any] = [
                "c": domain,
                "v": "mobile-app-\(ATTNConstants.sdkVersion)",
                "u": userIdentity.visitorId,
                "evs": evsArray,
                "tp": "apns",
                "type": "MARKETING"
            ]
            if let email = email { payload["email"] = email }
            if let phone = phone { payload["phone"] = phone }
            if !pushToken.isEmpty { payload["pt"] = pushToken }

            guard let url = URL(string: "https://mobile.attentivemobile.com/opt-in-subscriptions") else {
                Loggers.network.error("Invalid opt-in subscriptions URL")
                callback?(nil, nil, nil, ATTNError.badURL)
                return
            }

            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.timeoutInterval = 15
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("1", forHTTPHeaderField: "x-datadog-sampling-priority")
            request.httpBody = try? JSONSerialization.data(withJSONObject: payload, options: [])

            Loggers.network.debug("POST /opt-in-subscriptions payload: \(payload, privacy: .public)")

            let task = urlSession.dataTask(with: request) { data, response, error in
                if let error = error {
                    Loggers.network.error("Opt-in error: \(error.localizedDescription, privacy: .public)")
                } else if let http = response as? HTTPURLResponse {
                    Loggers.network.debug("----- Opt-In Subscriptions Result -----")
                    Loggers.network.debug("Status Code: \(http.statusCode, privacy: .public)")
                    Loggers.network.debug("Headers: \(http.allHeaderFields, privacy: .public)")
                    if http.statusCode >= 400 {
                        Loggers.network.error("Opt-in API returned status \(http.statusCode, privacy: .public)")
                    } else {
                        Loggers.network.debug("Opt-in successful: opted in email: \(email ?? "nil", privacy: .public), phone: \(phone ?? "nil", privacy: .public)")
                    }
                }
                if let data = data, let bodyStr = String(data: data, encoding: .utf8) {
                    Loggers.network.debug("Response Body:\n\(bodyStr, privacy: .public)")
                }
                callback?(data, url, response, error)
            }
            task.resume()
        }

        // MARK: - Opt-Out Subscriptions

        func sendOptOutMarketingSubscription(
            pushToken: String,
            email: String?,
            phone: String?,
            userIdentity: ATTNUserIdentity,
            callback: ATTNAPICallback?
        ) {
            Loggers.network.debug("Sending opt-out marketing subscription - Visitor ID: \(userIdentity.visitorId, privacy: .public), Push Token: \(pushToken, privacy: .public), Email: \(email ?? "nil", privacy: .public), Phone: \(phone ?? "nil", privacy: .public)")

            let evsJson  = userIdentity.buildExternalVendorIdsJson()
            let evsArray = (try? JSONSerialization.jsonObject(with: Data(evsJson.utf8))) as? [[String: String]] ?? []

            var payload: [String: Any] = [
                "c": domain,
                "v": "mobile-app-\(ATTNConstants.sdkVersion)",
                "u": userIdentity.visitorId,
                "evs": evsArray,
                "tp": "apns",
                "type": "MARKETING"
            ]
            if let email = email { payload["email"] = email }
            if let phone = phone { payload["phone"] = phone }
            if !pushToken.isEmpty { payload["pt"] = pushToken }

            guard let url = URL(string: "https://mobile.attentivemobile.com/opt-out-subscriptions") else {
                Loggers.network.error("Invalid opt-out subscriptions URL")
                callback?(nil, nil, nil, ATTNError.badURL)
                return
            }

            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.timeoutInterval = 15
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("1", forHTTPHeaderField: "x-datadog-sampling-priority")
            request.httpBody = try? JSONSerialization.data(withJSONObject: payload, options: [])

            Loggers.network.debug("POST /opt-out-subscriptions payload: \(payload, privacy: .public)")

            let task = urlSession.dataTask(with: request) { data, response, error in
                if let error = error {
                    Loggers.network.error("Opt-out error: \(error.localizedDescription, privacy: .public)")
                } else if let http = response as? HTTPURLResponse {
                    Loggers.network.debug("----- Opt-Out Subscriptions Result -----")
                    Loggers.network.debug("Status Code: \(http.statusCode, privacy: .public)")
                    Loggers.network.debug("Headers: \(http.allHeaderFields, privacy: .public)")
                    if http.statusCode >= 400 {
                        Loggers.network.error("Opt-out API returned status \(http.statusCode, privacy: .public)")
                    } else {
                        Loggers.network.debug("Opt-out successful: opted out email: \(email ?? "nil", privacy: .public), phone: \(phone ?? "nil", privacy: .public)")
                    }
                }
                if let data = data, let bodyStr = String(data: data, encoding: .utf8) {
                    Loggers.network.debug("Response Body:\n\(bodyStr, privacy: .public)")
                }
                callback?(data, url, response, error)
            }
            task.resume()
        }

    // MARK: - Update User

    // Internal note for maintainers and AI assistants:
    // ------------------------------------------------
    // This method is the single network call behind two public SDK operations:
    //
    //   1. **updateUser(email:phone:callback:)** — the user is switching identity.
    //      Called with a real email/phone and operationContext = "updateUser".
    //
    //   2. **clearUser()** — the user is logging out.
    //      Called with nil email/phone and operationContext = "clearUser".
    //      Sending an empty metadata dict ("m": {}) tells the server to detach
    //      the push token from the current user without associating it to a new
    //      email/phone. This is an internal implementation detail — SDK consumers
    //      should only see "clearUser" in logs, never "updateUser".
    //
    // The `operationContext` parameter controls how every log line is labelled so
    // that developer-facing console output always reflects the public API the
    // consumer actually called, not the underlying network mechanism.
    func updateUser(
        pushToken: String,
        userIdentity: ATTNUserIdentity,
        email: String? = nil,
        phone: String? = nil,
        operationContext: String = "updateUser",
        callback: ATTNAPICallback? = nil
    ) {
        Loggers.network.debug("\(operationContext, privacy: .public): sending request - Visitor ID: \(userIdentity.visitorId, privacy: .public), Push Token: \(pushToken, privacy: .public)")

        var meta: [String: Any] = [:]
        if let email = email?.trimmingCharacters(in: .whitespacesAndNewlines), !email.isEmpty {
            meta["email"] = email
        }
        if let phone = phone?.trimmingCharacters(in: .whitespacesAndNewlines), !phone.isEmpty {
            meta["phone"] = phone
        }

        var payload: [String: Any] = [
            "c": self.domain,
            "u": userIdentity.visitorId,
            "tp": "apns",
            "v": "mobile-app-\(ATTNConstants.sdkVersion)",
            "m": meta
        ]
        if !pushToken.isEmpty { payload["pt"] = pushToken }

        guard let url = URL(string: "https://mobile.attentivemobile.com:443/user-update") else {
            Loggers.network.error("\(operationContext, privacy: .public): invalid URL")
            callback?(nil, nil, nil, ATTNError.badURL)
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 15
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("1", forHTTPHeaderField: "x-datadog-sampling-priority")
        request.httpBody = try? JSONSerialization.data(withJSONObject: payload, options: [])

        Loggers.network.debug("\(operationContext, privacy: .public): POST /user-update payload: \(payload, privacy: .public)")

        let task = self.urlSession.dataTask(with: request) { data, response, error in
            if let error = error {
                Loggers.network.error("\(operationContext, privacy: .public): network error - \(error.localizedDescription, privacy: .public)")
            } else if let http = response as? HTTPURLResponse {
                Loggers.network.debug("----- \(operationContext, privacy: .public) Result -----")
                Loggers.network.debug("Status Code: \(http.statusCode, privacy: .public)")
                Loggers.network.debug("Headers: \(http.allHeaderFields, privacy: .public)")
                if http.statusCode >= 400 {
                    Loggers.network.error("\(operationContext, privacy: .public): API returned status \(http.statusCode, privacy: .public)")
                }
            }
            if let data = data, let bodyStr = String(data: data, encoding: .utf8) {
                Loggers.network.debug("Response Body:\n\(bodyStr, privacy: .public)")
            }
            callback?(data, url, response, error)
        }
        task.resume()
    }

    // MARK: - Inbox

    private static let inboxHost = "https://mobile.attentivemobile.com"

    /// Fetches the unread inbox message count for the current user.
    ///
    /// Per RFC: this endpoint is identifier-based and unauthenticated. The server scopes the
    /// response by resolving identity from the supplied push token (and other identifiers).
    func fetchInboxUnreadCount(
        pushToken: String,
        email: String?,
        phone: String?,
        visitorId: String
    ) async throws -> Int {
        Loggers.network.debug("Fetching inbox unread count - Visitor ID: \(visitorId, privacy: .public), Push Token: \(pushToken, privacy: .public)")
        let payload = inboxIdentityPayload(pushToken: pushToken, email: email, phone: phone, visitorId: visitorId)
        let decoded: InboxUnreadCountResponse = try await postInboxJSON(
            path: "/inbox/messages/unread/count",
            payload: payload,
            decoder: JSONDecoder()
        )
        Loggers.network.debug("Inbox unread count: \(decoded.unreadCount, privacy: .public)")
        return decoded.unreadCount
    }

    /// Fetches a page of inbox messages. See the doc comment on `ATTNAPIProtocol.fetchInboxMessages`.
    func fetchInboxMessages(
        pushToken: String,
        email: String?,
        phone: String?,
        visitorId: String,
        pageSize: Int,
        pageToken: String?
    ) async throws -> InboxResponse {
        Loggers.network.debug("Fetching inbox messages - Visitor ID: \(visitorId, privacy: .public), Push Token: \(pushToken, privacy: .public), Page Size: \(pageSize, privacy: .public), Page Token: \(pageToken ?? "nil", privacy: .public)")
        var payload = inboxIdentityPayload(pushToken: pushToken, email: email, phone: phone, visitorId: visitorId)
        payload["page_size"] = pageSize
        if let pageToken = pageToken, !pageToken.isEmpty {
            payload["page_token"] = pageToken
        }
        let decoded: InboxResponse = try await postInboxJSON(
            path: "/inbox/messages",
            payload: payload,
            decoder: Self.inboxJSONDecoder
        )
        Loggers.network.debug("Inbox messages fetched: count=\(decoded.messages.count, privacy: .public), hasNextPage=\(decoded.nextPageToken?.isEmpty == false, privacy: .public)")
        return decoded
    }

    /// Builds the identifier fields shared by every inbox endpoint: `c` (domain), `visitor_id`,
    /// and the optional `push_token` / `email` / `phone`. Push token is prefixed with `apns:`
    /// so the server can route it to APNs (Android sends `fcm:...`).
    private func inboxIdentityPayload(
        pushToken: String,
        email: String?,
        phone: String?,
        visitorId: String
    ) -> [String: Any] {
        var payload: [String: Any] = [
            "c": domain,
            "visitor_id": visitorId
        ]
        if !pushToken.isEmpty { payload["push_token"] = "apns:\(pushToken)" }
        if let email = email?.trimmingCharacters(in: .whitespacesAndNewlines), !email.isEmpty {
            payload["email"] = email
        }
        if let phone = phone?.trimmingCharacters(in: .whitespacesAndNewlines), !phone.isEmpty {
            payload["phone"] = phone
        }
        return payload
    }

    /// Shared POST + JSON-decode scaffolding for inbox endpoints. Maps non-2xx status to
    /// `inboxRequestFailed`, non-HTTP responses and decode failures to `inboxResponseDecodeFailed`,
    /// and bad URLs to `badURL`. All other transport errors propagate.
    private func postInboxJSON<T: Decodable>(
        path: String,
        payload: [String: Any],
        decoder: JSONDecoder
    ) async throws -> T {
        guard let url = URL(string: Self.inboxHost + path) else {
            Loggers.network.error("Invalid inbox URL for path \(path, privacy: .public)")
            throw ATTNError.badURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 15
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("1", forHTTPHeaderField: "x-datadog-sampling-priority")
        request.httpBody = try JSONSerialization.data(withJSONObject: payload, options: [])

        Loggers.network.debug("POST \(path, privacy: .public)")
        let (data, response) = try await dataTask(with: request)

        guard let http = response as? HTTPURLResponse else {
            Loggers.network.error("Inbox \(path, privacy: .public) returned a non-HTTP response")
            throw ATTNError.inboxResponseDecodeFailed
        }
        Loggers.network.debug("Inbox \(path, privacy: .public) status: \(http.statusCode, privacy: .public)")
        guard (200..<300).contains(http.statusCode) else {
            Loggers.network.error("Inbox \(path, privacy: .public) returned status \(http.statusCode, privacy: .public)")
            throw ATTNError.inboxRequestFailed(statusCode: http.statusCode)
        }

        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            Loggers.network.error("Failed to decode inbox \(path, privacy: .public) response: \(error.localizedDescription, privacy: .public)")
            throw ATTNError.inboxResponseDecodeFailed
        }
    }

    /// Marks the supplied messages as read on the server.
    ///
    /// PATCH /inbox/messages/read — identifier-based (visitor_id + push_token), body carries
    /// the list of message ids. The response echoes the per-message read status and the
    /// updated unread count so the caller can reconcile local state without a follow-up fetch.
    func markMessagesRead(
        pushToken: String,
        visitorId: String,
        messageIds: [String]
    ) async throws -> UpdateReadStatusResponse {
        Loggers.network.debug("Marking inbox messages read - Visitor ID: \(visitorId, privacy: .public), Push Token: \(pushToken, privacy: .public), Count: \(messageIds.count, privacy: .public)")

        let body = UpdateReadStatusRequest(
            visitorId: visitorId,
            pushToken: Self.inboxPushToken(pushToken),
            messageIds: messageIds
        )

        guard let url = URL(string: "https://mobile.attentivemobile.com/inbox/messages/read") else {
            Loggers.network.error("Invalid inbox mark-read URL")
            throw ATTNError.badURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.timeoutInterval = 15
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("1", forHTTPHeaderField: "x-datadog-sampling-priority")
        request.httpBody = try JSONEncoder().encode(body)

        Loggers.network.debug("PATCH /inbox/messages/read")

        let (data, response) = try await dataTask(with: request)

        guard let http = response as? HTTPURLResponse else {
            Loggers.network.error("Inbox mark-read returned a non-HTTP response")
            throw ATTNError.inboxResponseDecodeFailed
        }
        Loggers.network.debug("Inbox mark-read status code: \(http.statusCode, privacy: .public)")
        guard (200..<300).contains(http.statusCode) else {
            Loggers.network.error("Inbox mark-read API returned status \(http.statusCode, privacy: .public)")
            throw ATTNError.inboxRequestFailed(statusCode: http.statusCode)
        }

        do {
            return try JSONDecoder().decode(UpdateReadStatusResponse.self, from: data)
        } catch {
            Loggers.network.error("Failed to decode inbox mark-read response: \(error.localizedDescription, privacy: .public)")
            throw ATTNError.inboxResponseDecodeFailed
        }
    }

    /// The inbox backend expects push tokens namespaced by transport (e.g. `apns:<token>`).
    /// Returns `nil` for an empty token so `push_token` is omitted from the request body
    /// rather than sent as an empty (and unusable) identifier.
    private static func inboxPushToken(_ pushToken: String) -> String? {
        pushToken.isEmpty ? nil : "apns:\(pushToken)"
    }

    private static let inboxJSONDecoder: JSONDecoder = {
        let decoder = JSONDecoder()
        // Accept ISO-8601 timestamps with or without fractional seconds. Foundation's built-in
        // `.iso8601` strategy uses an ISO8601DateFormatter without `.withFractionalSeconds`, so
        // a payload like `"2026-07-15T14:22:31.847Z"` would throw and fail the whole page.
        let withFractional = ISO8601DateFormatter()
        withFractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let withoutFractional = ISO8601DateFormatter()
        withoutFractional.formatOptions = [.withInternetDateTime]
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let string = try container.decode(String.self)
            if let date = withFractional.date(from: string) ?? withoutFractional.date(from: string) {
                return date
            }
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Expected ISO-8601 date string, got \(string)"
            )
        }
        return decoder
    }()

    /// async bridge over `URLSession.dataTask(with:completionHandler:)` — `URLSession.data(for:)`
    /// is an extension method and can't be intercepted by `NSURLSessionMock`.
    private func dataTask(with request: URLRequest) async throws -> (Data, URLResponse) {
        try await withCheckedThrowingContinuation { continuation in
            let task = urlSession.dataTask(with: request) { data, response, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else if let data = data, let response = response {
                    continuation.resume(returning: (data, response))
                } else {
                    continuation.resume(throwing: URLError(.badServerResponse))
                }
            }
            task.resume()
        }
    }
}

fileprivate extension ATTNAPI {
    func sendEventInternal(event: ATTNEvent, userIdentity: ATTNUserIdentity, domain: String, callback: ATTNAPICallback?) {
        // Slice up the Event into individual EventRequests
        let requests = event.convertEventToRequests()

        for request in requests {
            sendEventInternalForRequest(request: request, userIdentity: userIdentity, domain: domain, callback: callback)
        }
    }

    func sendEventInternalForRequest(request: ATTNEventRequest, userIdentity: ATTNUserIdentity, domain: String, callback: ATTNAPICallback?) {
        guard let url = eventUrlProvider.buildUrl(for: request, userIdentity: userIdentity, domain: domain) else {
            Loggers.event.error("Invalid URL constructed for event request.")
            return
        }

        Loggers.event.debug("Building Event URL for '\(request.eventNameAbbreviation, privacy: .public)' - Visitor ID: \(userIdentity.visitorId, privacy: .public), URL: \(url, privacy: .public)")

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"

        let task = urlSession.dataTask(with: urlRequest) { data, response, error in
            if let error = error {
                Loggers.event.error("Error sending for event '\(request.eventNameAbbreviation, privacy: .public)'. Error: '\(error.localizedDescription, privacy: .public)'")
            } else if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode > 400 {
                Loggers.event.error("Error sending the event. Incorrect status code: '\(httpResponse.statusCode, privacy: .public)'")
            } else {
                Loggers.event.debug("Successfully sent event of type '\(request.eventNameAbbreviation, privacy: .public)'")
            }

            callback?(data, url, response, error)
        }

        task.resume()
    }

    func sendUserIdentityInternal(userIdentity: ATTNUserIdentity, domain: String, callback: ATTNAPICallback?) {
        guard let url = eventUrlProvider.buildUrl(for: userIdentity, domain: domain) else {
            Loggers.event.error("Invalid URL constructed for user identity.")
            return
        }

        Loggers.event.debug("Building Identity Event URL - Visitor ID: \(userIdentity.visitorId, privacy: .public), URL: \(url, privacy: .public)")

        var request = URLRequest(url: url)
        request.httpMethod = "POST"

        let task = urlSession.dataTask(with: request) { data, response, error in
            if let error = error {
                Loggers.event.error("Error sending user identity. Error: '\(error.localizedDescription, privacy: .public)'")
            } else if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode > 400 {
                Loggers.event.error("Error sending the event. Incorrect status code: '\(httpResponse.statusCode, privacy: .public)'")
            } else {
                Loggers.event.debug("Successfully sent user identity event")
            }

            callback?(data, url, response, error)
        }

        task.resume()
    }

}

extension ATTNAPI {
    static func isInvalidDomain(_ domain: String) -> Bool {
        let normalized = domain.lowercased()
        return normalized.contains("attn.tv") || normalized.contains("/") || normalized.contains(":")
    }


    /// Sends a new-style event payload to the `/mobile` endpoint.
    /// - Parameters:
    ///   - event: The typed event payload (ATTNBaseEvent<M>)
    ///   - eventRequest: The legacy request object for backward compatibility and URL building
    ///   - userIdentity: The current user identity
    ///   - callback: Optional callback for the API response
    func sendNewEvent<M: Codable>(
        event: ATTNBaseEvent<M>,
        eventRequest: ATTNEventRequest,
        userIdentity: ATTNUserIdentity,
        callback: ATTNAPICallback? = nil
    ) {
        guard let url = eventUrlProvider.buildNewEventEndpointUrl(
            for: eventRequest,
            userIdentity: userIdentity,
            domain: domain
        ) else {
            Loggers.network.error("Invalid /mobile event URL - Visitor ID: \(userIdentity.visitorId, privacy: .public)")
            callback?(nil, nil, nil, ATTNError.badURL)
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded; charset=utf-8", forHTTPHeaderField: "Content-Type")
        request.setValue("1", forHTTPHeaderField: "x-datadog-sampling-priority")

        do {
            // Encode the event to JSON with explicit null values
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = [.sortedKeys]
            let jsonData = try encoder.encode(event)

            // Convert JSON to string for logging
            let jsonString = String(data: jsonData, encoding: .utf8) ?? ""

            // URL-encode the JSON and wrap it in form data with key 'd'
            guard let encodedJson = jsonString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
                Loggers.network.error("Failed to URL-encode JSON payload")
                callback?(nil, url, nil, ATTNError.badURL)
                return
            }

            let requestBody = "d=\(encodedJson)"
            request.httpBody = requestBody.data(using: .utf8)

            Loggers.network.debug("""
                                ---- Sending /mobile Event ----
                                URL: \(url.absoluteString, privacy: .public)
                                JSON Payload: \(jsonString, privacy: .public)
                                Request Body: \(requestBody, privacy: .public)
                                --------------------------------
                                """)

            let task = urlSession.dataTask(with: request) { data, response, error in
                if let error = error {
                    Loggers.network.error("New event send error: \(error.localizedDescription, privacy: .public)")
                } else if let http = response as? HTTPURLResponse {
                    Loggers.network.debug("New event status code: \(http.statusCode, privacy: .public)")
                    if http.statusCode >= 400 {
                        Loggers.network.error("New event failed with HTTP status code \(http.statusCode, privacy: .public)")
                    }
                }
                callback?(data, url, response, error)
            }
            task.resume()
        } catch {
            Loggers.network.error("Encoding error for /mobile event: \(error.localizedDescription, privacy: .public)")
            callback?(nil, url, nil, error)
        }
    }

}
