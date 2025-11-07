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
  private enum RequestConstants {
    static var dtagUrlFormat: String { "https://cdn.attn.tv/%@/dtag.js" }
    static var regexPattern: String { "='([a-z0-9-]+)[.]attn[.]tv'" }
  }

  private var userAgentBuilder: ATTNUserAgentBuilderProtocol = ATTNUserAgentBuilder()
  private var eventUrlProvider: ATTNEventURLProviding = ATTNEventURLProvider()

  private(set) var urlSession: URLSession

  private let retryClient: ATTNRetryingNetworkClient
  private var lastPushTokenSendTime: Date?

  // MARK: ATTNAPIProtocol Properties
  var cachedGeoAdjustedDomain: String?
  var domain: String

  init(domain: String) {
    self.urlSession = URLSession.build(withUserAgent: userAgentBuilder.buildUserAgent())
    self.domain = domain
    self.cachedGeoAdjustedDomain = nil
    self.retryClient = ATTNRetryingNetworkClient(session: self.urlSession)
  }

  init(domain: String, urlSession: URLSession) {
    self.urlSession = urlSession
    self.domain = domain
    self.cachedGeoAdjustedDomain = nil
    self.retryClient = ATTNRetryingNetworkClient(session: self.urlSession)
  }

  func send(userIdentity: ATTNUserIdentity) {
    send(userIdentity: userIdentity, callback: nil)
  }

  func send(userIdentity: ATTNUserIdentity, callback: ATTNAPICallback?) {
    getGeoAdjustedDomain(domain: domain) { [weak self] geoAdjustedDomain, error in
      if let error = error {
        Loggers.network.error("Error sending user identity: \(error.localizedDescription)")
        return
      }

      guard let geoAdjustedDomain = geoAdjustedDomain else { return }
      self?.sendUserIdentityInternal(userIdentity: userIdentity, domain: geoAdjustedDomain, callback: callback)
    }
  }

  func send(event: ATTNEvent, userIdentity: ATTNUserIdentity) {
    send(event: event, userIdentity: userIdentity, callback: nil)
  }

  func send(event: ATTNEvent, userIdentity: ATTNUserIdentity, callback: ATTNAPICallback?) {
    getGeoAdjustedDomain(domain: domain) { [weak self] geoAdjustedDomain, error in
      if let error = error {
        Loggers.network.error("Error sending event: \(error.localizedDescription)")
        return
      }

      guard let geoAdjustedDomain = geoAdjustedDomain else { return }
      Loggers.network.debug("Successfully returned geoAdjustedDomain: \(geoAdjustedDomain, privacy: .public)")
      self?.sendEventInternal(event: event, userIdentity: userIdentity, domain: geoAdjustedDomain, callback: callback)
    }
  }

  func update(domain newDomain: String) {
    domain = newDomain
    cachedGeoAdjustedDomain = nil
  }

  func sendPushToken(_ pushToken: String,
                     userIdentity: ATTNUserIdentity,
                     authorizationStatus: UNAuthorizationStatus,
                     callback: ATTNAPICallback?) {
    //debounce to remove duplicate events; only allow events tracking at most once every 2 seconds
    let now = Date()
    if let last = lastPushTokenSendTime, now.timeIntervalSince(last) < 2 {
      Loggers.event.debug("Skipping duplicate sendPushToken due to debounce.")
      return
    }
    lastPushTokenSendTime = now

    getGeoAdjustedDomain(domain: domain) { [weak self] geoDomain, error in
      guard let self = self else { return }
      if let error = error {
        Loggers.network.error("Failed to get geo domain for push token: \(error.localizedDescription)")
        return
      }
      guard let geoDomain = geoDomain else { return }

      guard let url = self.eventUrlProvider.buildPushTokenUrl(
        for: userIdentity,
        domain: geoDomain) else {
        Loggers.network.error("Invalid push token URL")
        return
      }

      let evsJson     = userIdentity.buildExternalVendorIdsJson()
      let evsArray    = (try? JSONSerialization.jsonObject(with: Data(evsJson.utf8)))
      as? [[String:String]] ?? []
      let metadataJson = userIdentity.buildMetadataJson()
      let metadata    = (try? JSONSerialization.jsonObject(with: Data(metadataJson.utf8)))
      as? [String:String] ?? [:]

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

      let payload: [String:Any] = [
        "c": geoDomain,
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

      Loggers.network.debug("POST /token payload: \(payload)")

      retryClient.performRequestWithRetry(request, to: url) { data, sentURL, response, error in
        if let error = error {
          Loggers.network.error("Error sending push token: \(error.localizedDescription)")
        } else if let http = response as? HTTPURLResponse, http.statusCode >= 400 {
          Loggers.network.error("Push-token API returned status \(http.statusCode)")
        } else {
          Loggers.network.debug("Successfully sent push token")
        }
        callback?(data, url, response, error)
      }
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

      Loggers.network.debug("POST app open events payload: \(payload)")

      retryClient.performRequestWithRetry(request, to: url) { data, sentURL, response, error in
        if let error = error {
          Loggers.network.error("Error sending app events: \(error.localizedDescription)")
        } else if let http = response as? HTTPURLResponse, http.statusCode >= 400 {
          Loggers.network.error("AppEvents API returned status \(http.statusCode)")
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
      getGeoAdjustedDomain(domain: domain) { [weak self] geoDomain, geoError in
        guard let self = self else { return }

        if let geoError = geoError {
          Loggers.network.error("Opt-in: geo domain error: \(geoError.localizedDescription)")
          callback?(nil, nil, nil, geoError)
          return
        }
        guard let geoDomain = geoDomain else {
          Loggers.network.error("Opt-in: geo domain missing")
          callback?(nil, nil, nil, ATTNError.geoDomainUnavailable)
          return
        }

        let evsJson  = userIdentity.buildExternalVendorIdsJson()
        let evsArray = (try? JSONSerialization.jsonObject(with: Data(evsJson.utf8))) as? [[String:String]] ?? []

        var payload: [String: Any] = [
          "c": geoDomain,
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

        Loggers.network.debug("POST /opt-in-subscriptions payload: \(payload)")

        let task = self.urlSession.dataTask(with: request) { data, response, error in
          if let error = error {
            Loggers.network.error("Opt-in error: \(error.localizedDescription)")
          } else if let http = response as? HTTPURLResponse {
            Loggers.network.debug("----- Opt-In Subscriptions Result -----")
            Loggers.network.debug("Status Code: \(http.statusCode)")
            Loggers.network.debug("Headers: \(http.allHeaderFields)")
            if http.statusCode >= 400 {
              Loggers.network.error("Opt-in API returned status \(http.statusCode)")
            }
          }
          if let data = data, let bodyStr = String(data: data, encoding: .utf8) {
            Loggers.network.debug("Response Body:\n\(bodyStr)")
          }
          callback?(data, url, response, error)
        }
        task.resume()
      }
    }

    // MARK: - Opt-Out Subscriptions

    func sendOptOutMarketingSubscription(
      pushToken: String,
      email: String?,
      phone: String?,
      userIdentity: ATTNUserIdentity,
      callback: ATTNAPICallback?
    ) {
      getGeoAdjustedDomain(domain: domain) { [weak self] geoDomain, geoError in
        guard let self = self else { return }

        if let geoError = geoError {
          Loggers.network.error("Opt-out: geo domain error: \(geoError.localizedDescription)")
          callback?(nil, nil, nil, geoError)
          return
        }
        guard let geoDomain = geoDomain else {
          Loggers.network.error("Opt-out: geo domain missing")
          callback?(nil, nil, nil, ATTNError.geoDomainUnavailable)
          return
        }

        let evsJson  = userIdentity.buildExternalVendorIdsJson()
        let evsArray = (try? JSONSerialization.jsonObject(with: Data(evsJson.utf8))) as? [[String:String]] ?? []

        var payload: [String: Any] = [
          "c": geoDomain,
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

        Loggers.network.debug("POST /opt-out-subscriptions payload: \(payload)")

        let task = self.urlSession.dataTask(with: request) { data, response, error in
          if let error = error {
            Loggers.network.error("Opt-out error: \(error.localizedDescription)")
          } else if let http = response as? HTTPURLResponse {
            Loggers.network.debug("----- Opt-Out Subscriptions Result -----")
            Loggers.network.debug("Status Code: \(http.statusCode)")
            Loggers.network.debug("Headers: \(http.allHeaderFields)")
            if http.statusCode >= 400 {
              Loggers.network.error("Opt-out API returned status \(http.statusCode)")
            }
          }
          if let data = data, let bodyStr = String(data: data, encoding: .utf8) {
            Loggers.network.debug("Response Body:\n\(bodyStr)")
          }
          callback?(data, url, response, error)
        }
        task.resume()
      }
    }

  // MARK: - Update User

  func updateUser(
    pushToken: String,
    userIdentity: ATTNUserIdentity,
    email: String? = nil,
    phone: String? = nil,
    callback: ATTNAPICallback? = nil
  ) {
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
      Loggers.network.error("Invalid Update User URL")
      callback?(nil, nil, nil, ATTNError.badURL)
      return
    }

    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.timeoutInterval = 15
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue("1", forHTTPHeaderField: "x-datadog-sampling-priority")
    request.httpBody = try? JSONSerialization.data(withJSONObject: payload, options: [])

    Loggers.network.debug("POST /update_user payload: \(payload)")

    let task = self.urlSession.dataTask(with: request) { data, response, error in
      if let error = error {
        Loggers.network.error("Update User error: \(error.localizedDescription)")
      } else if let http = response as? HTTPURLResponse {
        Loggers.network.debug("----- Update User Result -----")
        Loggers.network.debug("Status Code: \(http.statusCode)")
        Loggers.network.debug("Headers: \(http.allHeaderFields)")
        if http.statusCode >= 400 {
          Loggers.network.error("UpdateUser API returned status \(http.statusCode)")
        }
      }
      if let data = data, let bodyStr = String(data: data, encoding: .utf8) {
        Loggers.network.debug("Response Body:\n\(bodyStr)")
      }
      callback?(data, url, response, error)
    }
    task.resume()
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

    Loggers.event.debug("Building Event URL: \(url)")

    var urlRequest = URLRequest(url: url)
    urlRequest.httpMethod = "POST"

    let task = urlSession.dataTask(with: urlRequest) { data, response, error in
      if let error = error {
        Loggers.event.error("Error sending for event '\(request.eventNameAbbreviation)'. Error: '\(error.localizedDescription)'")
      } else if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode > 400 {
        Loggers.event.error("Error sending the event. Incorrect status code: '\(httpResponse.statusCode)'")
      } else {
        Loggers.event.debug("Successfully sent event of type '\(request.eventNameAbbreviation)'")
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

    Loggers.event.debug("Building Identity Event URL: \(url)")

    var request = URLRequest(url: url)
    request.httpMethod = "POST"

    let task = urlSession.dataTask(with: request) { data, response, error in
      if let error = error {
        Loggers.event.error("Error sending user identity. Error: '\(error.localizedDescription)'")
      } else if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode > 400 {
        Loggers.event.error("Error sending the event. Incorrect status code: '\(httpResponse.statusCode)'")
      } else {
        Loggers.event.debug("Successfully sent user identity event")
      }

      callback?(data, url, response, error)
    }

    task.resume()
  }

  static func extractDomainFromTag(_ tag: String) -> String? {
    do {
      let regex = try NSRegularExpression(pattern: RequestConstants.regexPattern, options: [])
      let matchesCount = regex.numberOfMatches(in: tag, options: [], range: NSRange(location: 0, length: tag.utf16.count))

      guard matchesCount >= 1 else {
        Loggers.creative.debug("No Attentive domain found in the tag")
        return nil
      }

      guard let match = regex.firstMatch(in: tag, options: [], range: NSRange(location: 0, length: tag.utf16.count)) else {
        Loggers.creative.debug("No Attentive domain regex match object returned.")
        return nil
      }

      let domainRange = match.range(at: 1)
      guard domainRange.location != NSNotFound, let range = Range(domainRange, in: tag) else {
        Loggers.creative.debug("No match found for Attentive domain in the tag.")
        return nil
      }

      let regionalizedDomain = String(tag[range])
      Loggers.creative.debug("Identified regionalized attentive domain: \(regionalizedDomain)")
      return regionalizedDomain
    } catch {
      Loggers.creative.debug("Error building the domain regex. Error: '\(error.localizedDescription)'")
      return nil
    }
  }

}

extension ATTNAPI {
  func getGeoAdjustedDomain(domain: String, completionHandler: @escaping (String?, Error?) -> Void) {
    if let cachedDomain = cachedGeoAdjustedDomain {
      completionHandler(cachedDomain, nil)
      return
    }

    Loggers.network.debug("Getting the geoAdjustedDomain for domain '\(domain)'...")

    let urlString = String(format: RequestConstants.dtagUrlFormat, domain)
    guard let url = URL(string: urlString) else {
      Loggers.network.debug("Invalid URL format for domain '\(domain)'")
      completionHandler(nil, NSError(domain: "com.attentive.API", code: NSURLErrorBadURL, userInfo: nil))
      return
    }

    let request = URLRequest(url: url)
    let task = urlSession.dataTask(with: request) { [weak self] data, response, error in
      if let error = error {
        Loggers.network.error("Error getting the geo-adjusted domain for \(domain). Error: '\(error.localizedDescription)'")
        completionHandler(nil, error)
        return
      }

      guard let httpResponse = response as? HTTPURLResponse else {
        Loggers.network.error("Invalid response received.")
        completionHandler(nil, NSError(domain: "com.attentive.API", code: NSURLErrorUnknown, userInfo: nil))
        return
      }

      guard httpResponse.statusCode == 200, let data = data else {
        Loggers.network.error("Error getting the geo-adjusted domain for \(domain). Incorrect status code: '\(httpResponse.statusCode)'")
        completionHandler(nil, NSError(domain: "com.attentive.API", code: NSURLErrorBadServerResponse, userInfo: nil))
        return
      }

      let dataString = String(data: data, encoding: .utf8)
      guard let geoAdjustedDomain = ATTNAPI.extractDomainFromTag(dataString ?? "") else { return }

      if geoAdjustedDomain.isEmpty {
        Loggers.network.error("Invalid empty geo-adjusted domain")
        let error = NSError(domain: "com.attentive.API", code: NSURLErrorBadServerResponse, userInfo: nil)
        completionHandler(nil, error)
        return
      }

      self?.cachedGeoAdjustedDomain = geoAdjustedDomain
      completionHandler(geoAdjustedDomain, nil)
    }

    task.resume()
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
    getGeoAdjustedDomain(domain: domain) { [weak self] geoDomain, error in
      guard let self = self else { return }

      if let error = error {
        Loggers.network.error("Error fetching geo domain for /mobile event: \(error.localizedDescription)")
        callback?(nil, nil, nil, error)
        return
      }

      guard let geoDomain = geoDomain,
            let url = self.eventUrlProvider.buildNewEventEndpointUrl(
              for: eventRequest,
              userIdentity: userIdentity,
              domain: geoDomain
            ) else {
        Loggers.network.error("Invalid /mobile event URL")
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

        let formBody = "d=\(encodedJson)"
        request.httpBody = formBody.data(using: .utf8)

        Loggers.network.debug("""
                  ---- Sending /mobile Event ----
                  URL: \(url.absoluteString)
                  JSON Payload: \(jsonString)
                  Form Body: \(formBody)
                  --------------------------------
                  """)

        let task = self.urlSession.dataTask(with: request) { data, response, error in
          if let error = error {
            Loggers.network.error("New event send error: \(error.localizedDescription)")
          } else if let http = response as? HTTPURLResponse {
            Loggers.network.debug("New event status code: \(http.statusCode)")
            if http.statusCode >= 400 {
              Loggers.network.error("New event failed with HTTP status code \(http.statusCode)")
            }
          }
          callback?(data, url, response, error)
        }
        task.resume()
      } catch {
        Loggers.network.error("Encoding error for /mobile event: \(error.localizedDescription)")
        callback?(nil, url, nil, error)
      }
    }
  }

}
