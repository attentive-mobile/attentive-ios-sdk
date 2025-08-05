//
//  ATTNSDK.swift
//  attentive-ios-sdk-framework
//
//  Created by Vladimir - Work on 2024-05-27.
//

import Foundation
import WebKit

public typealias ATTNCreativeTriggerCompletionHandler = (String) -> Void

extension Notification.Name {
  static let didReceivePushOpen = Notification.Name("ATTNSDKDidReceivePushOpen")
}

@objc(ATTNSDK)
public final class ATTNSDK: NSObject {

  private var _containerView: UIView?
  private var latestPushToken: String?
  /// Holds exactly one pending deep-link URL (new taps overwrite old).
  private var pendingURL: URL?
  // Debounce mechanism to prevent duplicate events
  private var lastRegularOpenTime: Date?

  // Always prefer the in‐memory token, but fall back to the last‐saved UserDefaults value
  private var currentPushToken: String {
    if let token = latestPushToken, !token.isEmpty {
      return token
    }
    return UserDefaults.standard.string(forKey: "attentiveDeviceToken") ?? ""
  }

  // MARK: Instance Properties
  var parentView: UIView?
  var triggerHandler: ATTNCreativeTriggerCompletionHandler?
  var webView: WKWebView?

  private(set) var api: ATTNAPIProtocol
  private(set) var userIdentity: ATTNUserIdentity

  private var domain: String
  private var mode: ATTNSDKMode
  private var webViewHandler: ATTNWebViewHandling?

  /// Determinates if fatigue rules evaluation will be skipped for Creative. Default value is false.
  @objc public var skipFatigueOnCreative: Bool = false

  public init(domain: String, mode: ATTNSDKMode) {
    Loggers.creative.debug("Init ATTNSDKFramework v\(ATTNConstants.sdkVersion, privacy: .public), Mode: \(mode.rawValue, privacy: .public), Domain: \(domain, privacy: .public)")

    self.domain = domain
    self.mode = mode

    self.userIdentity = .init()
    self.api = ATTNAPI(domain: domain)

    super.init()

    // Proactively send app open events for cold launch
    handleAppDidBecomeActive()

    // Register app open events for when app is foregrounded
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(handleAppDidBecomeActive),
      name: UIApplication.didBecomeActiveNotification,
      object: nil
    )

    self.webViewHandler = ATTNWebViewHandler(webViewProvider: self)
    self.sendInfoEvent()
    self.initializeSkipFatigueOnCreatives()
  }

  @objc(initWithDomain:)
  public convenience init(domain: String) {
    self.init(domain: domain, mode: .production)
  }

  @available(swift, deprecated: 0.6, message: "Please use init(domain: String, mode: ATTNSDKMode) instead.")
  @objc(initWithDomain:mode:)
  public convenience init(domain: String, mode: String) {
    self.init(domain: domain, mode: ATTNSDKMode(rawValue: mode) ?? .production)
  }

  // MARK: Public API
  @objc(identify:)
  public func identify(_ userIdentifiers: [String: Any]) {
    userIdentity.mergeIdentifiers(userIdentifiers)
    api.send(userIdentity: userIdentity)
    Loggers.event.debug("Send User Identifiers: \(userIdentifiers)")
  }

  @objc(trigger:)
  public func trigger(_ view: UIView) {
    launchCreative(parentView: view)
  }

  @objc(trigger:handler:)
  public func trigger(_ view: UIView, handler: ATTNCreativeTriggerCompletionHandler?) {
    launchCreative(parentView: view, handler: handler)
  }

  @objc(trigger:creativeId:)
  public func trigger(_ view: UIView, creativeId: String) {
    launchCreative(parentView: view, creativeId: creativeId, handler: nil)
  }

  @objc(trigger:creativeId:handler:)
  public func trigger(_ view: UIView, creativeId: String, handler: ATTNCreativeTriggerCompletionHandler?) {
    launchCreative(parentView: view, creativeId: creativeId, handler: handler)
  }

  @objc(clearUser)
  public func clearUser() {
    userIdentity.clearUser()
    Loggers.creative.debug("Clear user. New visitor id: \(self.userIdentity.visitorId, privacy: .public)")
  }

  @objc(updateDomain:)
  public func update(domain: String) {
    guard self.domain != domain else { return }
    self.domain = domain
    api.update(domain: domain)
    Loggers.creative.debug("Updated SDK with new domain: \(domain)")
    api.send(userIdentity: userIdentity)
    Loggers.creative.debug("Retrigger Identity Event with new domain '\(domain)'")
  }

  // Ask the user for push‐notification permission and register with APNs if granted.
  @objc(registerForPushNotifications)
  public func registerForPushNotifications() {
    Loggers.event.debug("Requesting push‐notification authorization…")
    // Skip UNUserNotificationCenter usage in unit tests
    if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil {
      Loggers.event.debug("Skipping handleAppDidBecomeActive during XCTest run.")
      return
    }
    UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { [weak self] granted, error in
      if let error = error {
        Loggers.event.error("Push authorization error: \(error.localizedDescription)")
      }
      if !granted {
        Loggers.event.debug("""
                        Push notifications permission was denied.
                        To enable push, guide your user to go to Settings → Notifications → Your app.
                        """)
      }
      Loggers.event.debug("Push permission granted: \(granted)")
      guard granted else { return }
      self?.registerWithAPNsIfAuthorized()
    }
  }

  @objc(registerAppEvents:pushToken:subscriptionStatus:transport:callback:)
  public func registerAppEvents(
    _ events: [[String: Any]],
    pushToken: String,
    subscriptionStatus: String,
    transport: String = "apns",
    callback: ATTNAPICallback? = nil
  ) {
    api.sendAppEvents(pushToken: pushToken, subscriptionStatus: subscriptionStatus, transport: transport, events: events, userIdentity: userIdentity) { data, url, response, error in
      Loggers.event.debug("----- App Open Events Request Result -----")
      if let url = url {
        Loggers.event.debug("Request URL: \(url.absoluteString)")
      }
      if let http = response as? HTTPURLResponse {
        Loggers.event.debug("Status Code: \(http.statusCode)")
        Loggers.event.debug("Headers: \(http.allHeaderFields)")
      }
      if let d = data, let body = String(data: d, encoding: .utf8) {
        Loggers.event.debug("Response Body:\n\(body)")
      }
      if let error = error {
        Loggers.event.error("Error:\n\(error.localizedDescription)")
      }

      callback?(data, url, response, error)
    }
  }

  @objc(registerDeviceToken:authorizationStatus:callback:)
  public func registerDeviceToken(_ deviceToken: Data, authorizationStatus: UNAuthorizationStatus, callback: ATTNAPICallback? = nil
  ) {
    let tokenString = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
    Loggers.event.debug("APNs device‐token: \(tokenString)")
    UserDefaults.standard.set(tokenString, forKey: "attentiveDeviceToken")
    self.latestPushToken = tokenString
    //this is called after events are sent. we need a better way to persist this
    api.sendPushToken(tokenString, userIdentity: userIdentity, authorizationStatus: authorizationStatus) { data, url, response, error in
      Loggers.event.debug("----- Push-Token Request Result -----")
      if let url = url {
        Loggers.event.debug("Request URL: \(url.absoluteString)")
      }
      if let http = response as? HTTPURLResponse {
        Loggers.event.debug("Status Code: \(http.statusCode)")
        Loggers.event.debug("Headers: \(http.allHeaderFields)")
      }
      if let d = data, let body = String(data: d, encoding: .utf8) {
        Loggers.event.debug("Response Body:\n\(body)")
      }
      if let error = error {
        Loggers.event.error("Error:\n\(error.localizedDescription)")
      }

      callback?(data, url, response, error)
    }
  }

  @objc(registerForPushFailed:)
  public func failedToRegisterForPush(_ error: Error) {
    Loggers.event.error("Failed to register for remote notifications: \(error.localizedDescription)")
  }

  @objc public func handleRegularOpen(authorizationStatus: UNAuthorizationStatus) {
    //checks and resets push launch flag
    guard !ATTNLaunchManager.shared.resetPushLaunchFlag() else {
        Loggers.event.debug("Skipping regular open handler as push launch flag is set to true")
        return
      }
    //debounce to remove duplicate events; only allow app events tracking once every 2 seconds
    let now = Date()
    if let last = lastRegularOpenTime, now.timeIntervalSince(last) < 2 {
      Loggers.event.debug("Skipping duplicate handleRegularOpen due to debounce.")
      return
    }
    lastRegularOpenTime = now

    let alEvent: [String: Any] = [
      "ist": "al",
      "data": [
        "message_id": "",
        "send_id": "",
        "destination_token": currentPushToken,
        "company_id": "",
        "user_id": "",
        "message_type": "",
        "message_subtype": ""
      ]
    ]
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
    registerAppEvents([alEvent], pushToken: currentPushToken, subscriptionStatus: authorizationStatusString)
  }

  @objc public func handleForegroundPush(response: UNNotificationResponse, authorizationStatus: UNAuthorizationStatus) {
    let userInfo = response.notification.request.content.userInfo
    let data = (userInfo["attentiveCallbackData"] as? [String: Any]) ?? [:]
    // app open from push event
    let oEvent: [String: Any] = [
      "ist": "o",
      "data": data
    ]
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

    registerAppEvents([oEvent], pushToken: currentPushToken, subscriptionStatus: authorizationStatusString)

    guard let linkString = data["attentive_open_action_url"] as? String else {
      Loggers.network.debug("No deep link URL found in push notification")
      return
    }
    normalizeAndBroadcast(linkString)
  }

  @objc public func handlePushOpen(response: UNNotificationResponse, authorizationStatus: UNAuthorizationStatus) {
    ATTNLaunchManager.shared.launchedFromPush = true
    let userInfo = response.notification.request.content.userInfo
    print("entire payload: \(response)")
    let data = (userInfo["attentiveCallbackData"] as? [String: Any]) ?? [:]
    // app launch event
    let alEvent: [String: Any] = [
      "ist": "al",
      "data": data
    ]
    // app open from push event
    let oEvent: [String: Any] = [
      "ist": "o",
      "data": data
    ]
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
    registerAppEvents([alEvent,oEvent], pushToken: currentPushToken, subscriptionStatus: authorizationStatusString)

    guard let linkString = data["attentive_open_action_url"] as? String else {
      Loggers.network.debug("No deep link URL found in push notification")
      return
    }
    Loggers.network.debug("Broadcasting deep link URL found in push notification: \(linkString)")
    normalizeAndBroadcast(linkString)

  }

  /// If the client prefers polling instead of observing NotificationCenter, or if the NotificationCenter broadcast happens too early for listener to catch it,
  /// call this to retrieve (and clear) the pending URL.
  public func consumeDeepLink() -> URL? {
    defer { pendingURL = nil }
    let urlString = pendingURL?.absoluteString ?? ""
    Loggers.network.debug("Consuming pending deep link: \(urlString)")
    return pendingURL
  }

  // MARK: - Private Helpers

  private func registerWithAPNsIfAuthorized() {
    // Skip UNUserNotificationCenter usage in unit tests
    if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil {
      Loggers.event.debug("Skipping handleAppDidBecomeActive during XCTest run.")
      return
    }
    UNUserNotificationCenter.current().getNotificationSettings { settings in
      Loggers.event.debug("Notification settings: \(settings.authorizationStatus.rawValue)")
      switch settings.authorizationStatus {
      case .authorized:
        DispatchQueue.main.async {
          Loggers.event.debug("Push permission authorized. Registering for remote notifications with APNs")
          UIApplication.shared.registerForRemoteNotifications()
        }

      case .provisional:
        Loggers.event.debug("Provisional push permission granted; registering with APNs")
        DispatchQueue.main.async {
          UIApplication.shared.registerForRemoteNotifications()
        }

      case .ephemeral:
        Loggers.event.debug("Ephemeral push permission granted; registering with APNs")
        DispatchQueue.main.async {
          UIApplication.shared.registerForRemoteNotifications()
        }

      case .notDetermined:
        // Shouldn’t happen, logging it in case
        Loggers.event.debug("Push notifications permission not determined yet.")

      @unknown default:
        // Future-proofing in case Apple adds new cases
        Loggers.event.error("Unknown UNAuthorizationStatus: \(settings.authorizationStatus.rawValue)")
      }
    }

    DispatchQueue.main.async {
      Loggers.event.debug("Registering for remote notifications with APNs")
      UIApplication.shared.registerForRemoteNotifications()
    }
  }

  @objc private func handleAppDidBecomeActive() {
    // Skip UNUserNotificationCenter usage in unit tests
    if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil {
      Loggers.event.debug("Skipping handleAppDidBecomeActive during XCTest run.")
      return
    }
    UNUserNotificationCenter.current().getNotificationSettings { [weak self] settings in
      guard let self = self else { return }
      DispatchQueue.main.async {
        self.handleRegularOpen(authorizationStatus: settings.authorizationStatus)
      }
    }
  }

  /// Normalize a raw string into a URL, stash it, and immediately post a notification.
  private func normalizeAndBroadcast(_ rawString: String) {
    let trimmed = rawString.trimmingCharacters(in: .whitespacesAndNewlines)
    var candidateURL: URL?

    if let trimmedURL = URL(string: trimmed), trimmedURL.scheme != nil {
      candidateURL = trimmedURL
    }

    guard let validURL = candidateURL else {
      Loggers.network.error("SDK: Unable to form URL from string: '\(trimmed)'")
      return
    }

    pendingURL = validURL
    Loggers.network.debug("Broadcasting ATTNSDKDeepLinkReceived with URL: \(validURL)")
    NotificationCenter.default.post(
      name: .ATTNSDKDeepLinkReceived,
      object: nil,
      userInfo: ["attentivePushDeeplinkUrl": validURL]
    )
  }
}

// MARK: ATTNWebViewProviding
extension ATTNSDK: ATTNWebViewProviding {
  var containerView: UIView? {
    get { _containerView }
    set { _containerView = newValue }
  }

  func getDomain() -> String { domain }

  func getMode() -> ATTNSDKMode { mode }

  func getUserIdentity() -> ATTNUserIdentity { userIdentity }
}

// MARK: Private Helpers
fileprivate extension ATTNSDK {
  func sendInfoEvent() {
    api.send(event: ATTNInfoEvent(), userIdentity: userIdentity)
  }

  func launchCreative(
    parentView view: UIView,
    creativeId: String? = nil,
    handler: ATTNCreativeTriggerCompletionHandler? = nil
  ) {
    webViewHandler?.launchCreative(parentView: view, creativeId: creativeId, handler: handler)
  }
}

// MARK: Internal Helpers
extension ATTNSDK {
  convenience init(domain: String, mode: ATTNSDKMode, urlBuilder: ATTNCreativeUrlProviding) {
    self.init(domain: domain, mode: mode)
    self.webViewHandler = ATTNWebViewHandler(webViewProvider: self, creativeUrlBuilder: urlBuilder)
  }

  convenience init(api: ATTNAPIProtocol, urlBuilder: ATTNCreativeUrlProviding? = nil) {
    self.init(domain: api.domain)
    self.api = api
    guard let urlBuilder = urlBuilder else { return }
    self.webViewHandler = ATTNWebViewHandler(webViewProvider: self, creativeUrlBuilder: urlBuilder)
  }
}
