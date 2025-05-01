//
//  ATTNSDK.swift
//  attentive-ios-sdk-framework
//
//  Created by Vladimir - Work on 2024-05-27.
//

import Foundation
import WebKit

public typealias ATTNCreativeTriggerCompletionHandler = (String) -> Void

@objc(ATTNSDK)
public final class ATTNSDK: NSObject {

  private var _containerView: UIView?

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

  @objc(registerDeviceToken:)
  public func registerDeviceToken(_ deviceToken: Data) {
    let tokenString = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
    Loggers.event.debug("APNs device‐token: \(tokenString)")
    let callback: ATTNAPICallback = { data, url, response, error in
      print("----- Push-Token Request Result -----")

      if let url = url {
        print("Request URL: \(url.absoluteString)")
      }

      if let httpResponse = response as? HTTPURLResponse {
        print("Status Code: \(httpResponse.statusCode)")
        print("Headers: \(httpResponse.allHeaderFields)")
      }

      if let data = data, let body = String(data: data, encoding: .utf8) {
        print("Response Body:\n\(body)")
      }

      if let error = error {
        print("Error:\n\(error.localizedDescription)")
      }
    }
    api.sendPushToken(tokenString, for: userIdentity, callback: callback)
    // TODO:
    //api.send(deviceToken: tokenString)
    //api.send(notificationStatus: notificationStatus)
    //api.send(appEvent: appEvent)
  }

  @objc(registerForPushFailed:)
  public func failedToRegisterForPush(_ error: Error) {
    Loggers.event.error("Failed to register for remote notifications: \(error.localizedDescription)")
  }

  /// Call this from AppDelegate’s `userNotificationCenter(_:willPresent:withCompletionHandler:)`
  @objc(handleForegroundNotification:completionHandler:)
  public func handleForegroundNotification(
    _ userInfo: [AnyHashable: Any],
    completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    Loggers.event.debug("Foreground Notification received: \(userInfo)")
    //TODO: api.send(pushNotificationEvent: userInfo)

    let presentationOptions: UNNotificationPresentationOptions = [.alert, .sound, .badge]
    Loggers.event.debug("Presenting notification with options: \(presentationOptions.rawValue)")
    completionHandler(presentationOptions)
  }

  /// Call this from AppDelegate’s `userNotificationCenter(_:didReceive:withCompletionHandler:)`
  @objc(handleBackgroundNotification:completionHandler:)
  public func handleBackgroundNotification(
    _ userInfo: [AnyHashable: Any],
    completionHandler: @escaping () -> Void
  ) {
    Loggers.event.debug("Background Notification received: \(userInfo)")
    //api.send(pushNotificationEvent: userInfo)
    completionHandler()
  }

  // MARK: - Private Helpers

  private func registerWithAPNsIfAuthorized() {
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
