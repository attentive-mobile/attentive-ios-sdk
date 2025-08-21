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

public enum ATTNSDKError: Error {
  case initializationFailed
}

@objc(ATTNSDK)
public final class ATTNSDK: NSObject {

  private var _containerView: UIView?
  private var latestPushToken: String?

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

  public static func initialize(
      domain: String,
      mode: ATTNSDKMode = .production,
      completion: @escaping (Result<ATTNSDK, Error>) -> Void) {
        let sdk = ATTNSDK(domain: domain, mode: mode)
        DispatchQueue.global(qos: .userInitiated).async {
          let setupSucceeded = sdk.webViewHandler != nil
          DispatchQueue.main.async {
            if setupSucceeded {
              completion(.success(sdk))
            } else {
              completion(.failure(ATTNSDKError.initializationFailed))
            }
          }
        }
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

  @objc(optInMarketingSubscriptionWithEmail:phone:callback:)
  public func optInMarketingSubscription(
    email: String? = nil,
    phone: String? = nil,
    callback: ATTNAPICallback? = nil
  ) {
    let email = normalize(email)
    let phone = normalize(phone)

    guard email != nil || phone != nil else {
      Loggers.event.error("Opt-in: missing email/phone")
      callback?(nil, nil, nil, ATTNError.missingContactInfo)
      return
    }

    let pushToken = self.latestPushToken
    ?? UserDefaults.standard.string(forKey: "attentiveDeviceToken")
    ?? ""

    api.sendOptInMarketingSubscription(
      pushToken: pushToken,
      email: email,
      phone: phone,
      userIdentity: userIdentity,
      callback: callback
    )
  }

  // Convenience overloads (clear call sites / Obj‑C selectors)

  @objc(optInMarketingSubscriptionWithEmail:callback:)
  public func optInMarketingSubscription(
    email: String,
    callback: ATTNAPICallback? = nil
  ) {
    optInMarketingSubscription(email: email, phone: nil, callback: callback)
  }

  @objc(optInMarketingSubscriptionWithPhone:callback:)
  public func optInMarketingSubscription(
    phone: String,
    callback: ATTNAPICallback? = nil
  ) {
    optInMarketingSubscription(email: nil, phone: phone, callback: callback)
  }

  // MARK: - Small helpers
  private func normalize(_ value: String?) -> String? {
    let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines)
    return (trimmed?.isEmpty == false) ? trimmed : nil
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
