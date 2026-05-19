//
//  ATTNSDK.swift
//  attentive-ios-sdk-framework
//
//  Created by Vladimir - Work on 2024-05-27.
//

import Foundation
import UserNotifications
import WebKit

public typealias ATTNCreativeTriggerCompletionHandler = (String) -> Void

extension Notification.Name {
    static let didReceivePushOpen = Notification.Name("ATTNSDKDidReceivePushOpen")
}

@available(*, deprecated, message: "Use ATTNError.initializationFailed instead")
public enum ATTNSDKError: Error {
    case initializationFailed
    case missingPushToken
}

extension UNAuthorizationStatus {
    var stringValue: String {
        switch self {
        case .notDetermined: return "notDetermined"
        case .denied:        return "denied"
        case .authorized:    return "authorized"
        case .provisional:   return "provisional"
        case .ephemeral:     return "ephemeral"
        @unknown default:    return "unknown"
        }
    }
}

@objc(ATTNSDK)
public final class ATTNSDK: NSObject {

    private var _containerView: UIView?
    private let pushTokenStore = PushTokenStore()
    private let marketingQueue = DispatchQueue(label: "com.attentive.sdk.MarketingQueue", qos: .userInitiated)
    /// All access to `pendingMarketingRequests` and `pendingMarketingExpiryTimer` is serialized through `marketingQueue`.
    private var pendingMarketingRequests: [PendingMarketingRequest] = []
    private var pendingMarketingExpiryTimer: DispatchSourceTimer?
    private let pendingMarketingTTL: TimeInterval = 60
    private let stateLock = NSLock()
    /// Holds exactly one pending deep-link URL (new taps overwrite old).
    private var _pendingURL: URL?
    // Debounce mechanism to prevent duplicate events
    private var _lastRegularOpenTime: Date?

    var currentPushToken: String { pushTokenStore.token }

    // MARK: Instance Properties
    var parentView: UIView?
    var triggerHandler: ATTNCreativeTriggerCompletionHandler?
    var webView: WKWebView?

    private(set) var api: ATTNAPIProtocol
    private(set) var userIdentity: ATTNUserIdentity

    @objc public internal(set) var domain: String
    private var mode: ATTNSDKMode
    private var webViewHandler: ATTNWebViewHandling?

    /// The visitor ID for the current user. Rotates when `clearUser()` is called.
    @objc public var visitorId: String { userIdentity.visitorId }

    /// The marketing version of the SDK (e.g. `"2.0.13"`).
    @objc public static var sdkVersion: String { ATTNConstants.sdkVersion }

    /// Determinates if fatigue rules evaluation will be skipped for Creative. Default value is false.
    @objc public var skipFatigueOnCreative: Bool = false

    /// When `true` (default), the SDK acts as the device's push provider: it requests push
    /// permission, registers with APNs, tracks push tokens, and handles incoming push events.
    /// Set to `false` if another provider owns push on this device; the SDK will then skip
    /// all push registration, token storage, and push-event handling.
    @objc public let pushEnabled: Bool

    /// Routes legacy `record(event:)` calls through the v2 `/mobile` endpoint instead of `/e`.
    @objc public var useV2Endpoint: Bool = false

    public init(domain: String, mode: ATTNSDKMode, pushEnabled: Bool = true) {
        Loggers.creative.debug("Initializing ATTNSDK v\(ATTNConstants.sdkVersion, privacy: .public), Mode: \(mode.rawValue, privacy: .public), Domain: \(domain, privacy: .public), PushEnabled: \(pushEnabled, privacy: .public)")

        self.domain = domain
        self.mode = mode
        self.pushEnabled = pushEnabled

        self.userIdentity = .init()
        self.api = ATTNAPI(domain: domain)

        super.init()

        if ATTNAPI.isInvalidDomain(domain) {
            let message = ATTNError.invalidDomain.localizedDescription
            Loggers.creative.error("Invalid domain provided: \(domain, privacy: .public)")
            Loggers.creative.error("\(message)")
            assertionFailure(message)
            return
        }

        // Register app open events for when app is foregrounded.
        // Skipped when another provider owns push on this device.
        if pushEnabled {
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(handleAppDidBecomeActive),
                name: UIApplication.didBecomeActiveNotification,
                object: nil
            )
        }

        self.webViewHandler = ATTNWebViewHandler(webViewProvider: self)
        self.sendInfoEvent()
        self.initializeSkipFatigueOnCreatives()

        Loggers.creative.debug("ATTNSDK initialization successful - Visitor ID: \(self.userIdentity.visitorId, privacy: .public), Domain: \(domain, privacy: .public)")
    }

    deinit {
        pendingMarketingExpiryTimer?.cancel()
        pendingMarketingExpiryTimer = nil
        pendingMarketingRequests.removeAll()
    }

    @objc(initWithDomain:)
    public convenience init(domain: String) {
        self.init(domain: domain, mode: .production)
    }

    @available(swift, deprecated: 0.6, message: "Please use init(domain:mode:pushEnabled:) instead.")
    @objc(initWithDomain:mode:)
    public convenience init(domain: String, mode: String) {
        self.init(domain: domain, mode: ATTNSDKMode(rawValue: mode) ?? .production)
    }

    /// Objective-C initializer with push-provider opt-out. Pass `mode` as the raw value
    /// of `ATTNSDKMode` ("debug" or "production"); unrecognized values default to production.
    @objc(initWithDomain:mode:pushEnabled:)
    public convenience init(domain: String, mode: String, pushEnabled: Bool) {
        self.init(domain: domain, mode: ATTNSDKMode(rawValue: mode) ?? .production, pushEnabled: pushEnabled)
    }

    /// Async initializer that reports success/failure after background setup.
    public static func initialize(
        domain: String,
        mode: ATTNSDKMode = .production,
        pushEnabled: Bool = true,
        completion: @escaping (Result<ATTNSDK, Error>) -> Void) {
            if ATTNAPI.isInvalidDomain(domain) {
                Loggers.creative.error("ATTNSDK initialization failed - invalid domain: \(domain, privacy: .public)")
                DispatchQueue.main.async {
                    completion(.failure(ATTNError.invalidDomain))
                }
                return
            }
            let sdk = ATTNSDK(domain: domain, mode: mode, pushEnabled: pushEnabled)
            DispatchQueue.global(qos: .userInitiated).async {
                let setupSucceeded = sdk.webViewHandler != nil
                DispatchQueue.main.async {
                    if setupSucceeded {
                        Loggers.creative.debug("ATTNSDK async initialization successful - Visitor ID: \(sdk.userIdentity.visitorId, privacy: .public)")
                        completion(.success(sdk))
                    } else {
                        Loggers.creative.error("ATTNSDK async initialization failed - webViewHandler setup unsuccessful")
                        completion(.failure(ATTNError.initializationFailed))
                    }
                }
            }
        }

    // MARK: Public API
    @objc(identify:)
    public func identify(_ userIdentifiers: [String: Any]) {
        Loggers.event.debug("Identifying user - Visitor ID: \(self.userIdentity.visitorId, privacy: .public), Identifiers: \(userIdentifiers, privacy: .public)")
        userIdentity.mergeIdentifiers(userIdentifiers)
        api.send(userIdentity: userIdentity)
        Loggers.event.debug("User identity sent successfully - Visitor ID: \(self.userIdentity.visitorId, privacy: .public)")
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

    /// Clears all user identifiers and detaches the push token from the current user.
    ///
    /// Call this when the user logs out. The SDK will:
    /// 1. Reset all local identifiers (email, phone, etc.) and generate a new anonymous visitor ID.
    /// 2. If a push token is registered, tell the server to detach it from the previous user so
    ///    they stop receiving push notifications on this device.
    ///
    /// After `clearUser()` returns, the device is in an anonymous state. The next call to
    /// `identify(_:)` or `updateUser(email:phone:callback:)` will associate the device with a
    /// new user.
    ///
    /// - Note: If no push token has been registered (via `registerDeviceToken`), the server-side
    ///   detach is skipped — identifiers are still cleared locally.
    ///
    /// Internal implementation detail (for maintainers / AI assistants):
    /// Under the hood this calls the same `/user-update` endpoint as `updateUser`, but with
    /// empty email and phone. The `operationContext: "clearUser"` parameter ensures all logs
    /// are labelled "clearUser" so SDK consumers never see "updateUser" in their console when
    /// they only called `clearUser()`.
    @objc(clearUser)
    public func clearUser() {
        clearUserIdentifiers()

        let pushToken = currentPushToken
        guard !pushToken.isEmpty else {
            Loggers.event.debug("clearUser: skipping push token detach — no push token available")
            return
        }

        Loggers.event.debug("clearUser: detaching push token from previous user - Visitor ID: \(self.userIdentity.visitorId, privacy: .public)")
        api.updateUser(
            pushToken: pushToken,
            userIdentity: userIdentity,
            email: nil,
            phone: nil,
            operationContext: "clearUser",
            callback: nil
        )
    }

    /// Clears user identifiers and generates a new visitor ID. **Local only — no network call.**
    ///
    /// Both `clearUser()` and `updateUser(email:phone:callback:)` call this as their first step.
    /// The new visitor ID is used in any subsequent API call so the server treats the device as
    /// a fresh anonymous user.
    func clearUserIdentifiers() {
        let oldVisitorId = userIdentity.visitorId
        userIdentity.clearUser()
        Loggers.creative.debug("User cleared successfully - Old Visitor ID: \(oldVisitorId, privacy: .public), New Visitor ID: \(self.userIdentity.visitorId, privacy: .public)")
    }

    @objc(updateDomain:)
    public func update(domain: String) {
        update(domain: domain, completion: nil)
    }

    @objc(updateDomain:completion:)
    public func update(domain: String, completion: ((Error?) -> Void)?) {
        guard self.domain != domain else {
            Loggers.creative.debug("Domain update skipped - requested domain matches current domain: \(domain, privacy: .public)")
            DispatchQueue.main.async { completion?(nil) }
            return
        }
        if ATTNAPI.isInvalidDomain(domain) {
            Loggers.creative.error("Invalid domain provided: \(domain, privacy: .public)")
            Loggers.creative.error("\(ATTNError.invalidDomain.localizedDescription)")
            if completion == nil {
                assertionFailure(ATTNError.invalidDomain.localizedDescription)
            }
            DispatchQueue.main.async { completion?(ATTNError.invalidDomain) }
            return
        }
        updateDomainInternal(domain)
        DispatchQueue.main.async { completion?(nil) }
    }

    private func updateDomainInternal(_ domain: String) {
        let oldDomain = self.domain
        self.domain = domain
        api.update(domain: domain)
        Loggers.creative.debug("Domain updated successfully - Old Domain: \(oldDomain, privacy: .public), New Domain: \(domain, privacy: .public), Visitor ID: \(self.userIdentity.visitorId, privacy: .public)")
        api.send(userIdentity: userIdentity)
        Loggers.creative.debug("Identity event sent with new domain - Domain: \(domain, privacy: .public), Visitor ID: \(self.userIdentity.visitorId, privacy: .public)")
    }

    // MARK: Push Permissions & Token

    /// Ask the user for push‐notification permission and register with APNs if granted.
    @objc(registerForPushNotificationsWithCompletion:)
    public func registerForPushNotifications(completion: ((Bool, Error?) -> Void)? = nil) {
        guard pushEnabled else {
            Loggers.event.debug("registerForPushNotifications skipped: pushEnabled is false")
            completion?(false, nil)
            return
        }
        Loggers.event.debug("Requesting push-notification authorization…")
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { [weak self] granted, error in
            if let error = error {
                Loggers.event.error("Push authorization error: \(error.localizedDescription, privacy: .public)")
            }
            if !granted {
                Loggers.event.debug("""
                        Push notifications permission was denied.
                        To enable push, guide your user to go to Settings → Notifications → Your app.
                        """)
            }
            Loggers.event.debug("Push permission granted: \(granted, privacy: .public)")
            if granted {
                self?.registerWithAPNsIfAuthorized()
            }
            completion?(granted, error)
        }
    }

    @objc(registerDeviceToken:authorizationStatus:callback:)
    public func registerDeviceToken(_ deviceToken: Data, authorizationStatus: UNAuthorizationStatus, callback: ATTNAPICallback? = nil
    ) {
        guard pushEnabled else {
            Loggers.event.debug("registerDeviceToken skipped: pushEnabled is false")
            callback?(nil, nil, nil, nil)
            return
        }
        let tokenString = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
        Loggers.event.debug("Registering device token - Visitor ID: \(self.userIdentity.visitorId, privacy: .public), Push Token: \(tokenString, privacy: .public), Auth Status: \(authorizationStatus.stringValue, privacy: .public)")
        pushTokenStore.token = tokenString
        flushPendingMarketingRequests(with: tokenString)
        // this is called after events are sent. we need a better way to persist this
        api.sendPushToken(tokenString, userIdentity: userIdentity, authorizationStatus: authorizationStatus) { data, url, response, error in
            Loggers.event.debug("----- Push-Token Request Result -----")
            if let url = url {
                Loggers.event.debug("Request URL: \(url.absoluteString, privacy: .public)")
            }
            if let http = response as? HTTPURLResponse {
                Loggers.event.debug("Status Code: \(http.statusCode, privacy: .public)")
                Loggers.event.debug("Headers: \(http.allHeaderFields, privacy: .public)")
                if http.isSuccessful {
                    Loggers.event.debug("Device token registration successful - Push Token: \(tokenString, privacy: .public)")
                } else {
                    Loggers.event.error("Device token registration failed with status code: \(http.statusCode, privacy: .public)")
                }
            }
            if let d = data, let body = String(data: d, encoding: .utf8) {
                Loggers.event.debug("Response Body:\n\(body, privacy: .public)")
            }
            if let error = error {
                Loggers.event.error("Device token registration error: \(error.localizedDescription, privacy: .public)")
            }

            callback?(data, url, response, error)
        }
    }

    @objc(registerForPushFailed:)
    public func failedToRegisterForPush(_ error: Error) {
        guard pushEnabled else {
            Loggers.event.debug("failedToRegisterForPush skipped: pushEnabled is false")
            return
        }
        Loggers.event.error("Failed to register for remote notifications: \(error.localizedDescription, privacy: .public)")
    }

    // MARK: App Events

    @objc(registerAppEvents:pushToken:subscriptionStatus:transport:callback:)
    public func registerAppEvents(
        _ events: [[String: Any]],
        pushToken: String,
        subscriptionStatus: String,
        transport: String = "apns",
        callback: ATTNAPICallback? = nil
    ) {
        if pushToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            Loggers.event.error("registerAppEvents aborted: missing push token - Visitor ID: \(self.userIdentity.visitorId, privacy: .public)")
            callback?(nil, nil, nil, ATTNSDKError.missingPushToken)
            return
        }
        Loggers.event.debug("Registering app events - Visitor ID: \(self.userIdentity.visitorId, privacy: .public), Push Token: \(pushToken, privacy: .public), Subscription Status: \(subscriptionStatus, privacy: .public), Event Count: \(events.count, privacy: .public)")
        api.sendAppEvents(pushToken: pushToken, subscriptionStatus: subscriptionStatus, transport: transport, events: events, userIdentity: userIdentity) { data, url, response, error in
            Loggers.event.debug("----- App Open Events Request Result -----")
            if let url = url {
                Loggers.event.debug("Request URL: \(url.absoluteString, privacy: .public)")
            }
            if let http = response as? HTTPURLResponse {
                Loggers.event.debug("Status Code: \(http.statusCode, privacy: .public)")
                Loggers.event.debug("Headers: \(http.allHeaderFields, privacy: .public)")
                if http.isSuccessful {
                    Loggers.event.debug("App events sent successfully")
                } else {
                    Loggers.event.error("App events failed with status code: \(http.statusCode, privacy: .public)")
                }
            }
            if let d = data, let body = String(data: d, encoding: .utf8) {
                Loggers.event.debug("Response Body:\n\(body, privacy: .public)")
            }
            if let error = error {
                Loggers.event.error("App events error: \(error.localizedDescription, privacy: .public)")
            }

            callback?(data, url, response, error)
        }
    }

    @objc public func handleRegularOpen(pushToken: String? = nil, authorizationStatus: UNAuthorizationStatus) {
        guard pushEnabled else {
            Loggers.event.debug("handleRegularOpen skipped: pushEnabled is false")
            return
        }
        Loggers.event.debug("Handling regular app open - Visitor ID: \(self.userIdentity.visitorId, privacy: .public), Push Token: \(self.currentPushToken, privacy: .public), Auth Status: \(authorizationStatus.stringValue, privacy: .public)")

        // checks and resets push launch flag
        guard !ATTNLaunchManager.shared.resetPushLaunchFlag() else {
            Loggers.event.debug("Skipping regular open handler as push launch flag is set to true")
            return
        }
        // debounce to remove duplicate events; only allow app events tracking once every 2 seconds
        let now = Date()
        let shouldSkip: Bool = stateLock.withLock {
            if let last = _lastRegularOpenTime, now.timeIntervalSince(last) < 2 {
                return true
            }
            _lastRegularOpenTime = now
            return false
        }
        if shouldSkip {
            Loggers.event.debug("Skipping duplicate handleRegularOpen due to debounce.")
            return
        }

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
        registerAppEvents([alEvent], pushToken: currentPushToken, subscriptionStatus: authorizationStatus.stringValue)
    }

    @objc public func handleForegroundPush(response: UNNotificationResponse, authorizationStatus: UNAuthorizationStatus) {
        guard pushEnabled else {
            Loggers.event.debug("handleForegroundPush skipped: pushEnabled is false")
            return
        }
        Loggers.event.debug("Handling foreground push notification - Visitor ID: \(self.userIdentity.visitorId, privacy: .public), Push Token: \(self.currentPushToken, privacy: .public), Auth Status: \(authorizationStatus.stringValue, privacy: .public)")
        let userInfo = response.notification.request.content.userInfo
        Loggers.event.debug("Push notification payload: \(userInfo, privacy: .public)")
        let callbackData = (userInfo["attentiveCallbackData"] as? [String: Any]) ?? [:]
        let escapedData = escapeJSONDictionary(callbackData)
        Loggers.event.debug("Escaped attentiveCallbackData for handleForegroundPush: \(escapedData, privacy: .public)")
        // app open from push event
        let oEvent: [String: Any] = [
            "ist": "o",
            "data": escapedData
        ]

        registerAppEvents([oEvent], pushToken: currentPushToken, subscriptionStatus: authorizationStatus.stringValue)

        guard let linkString = escapedData["attentive_open_action_url"] as? String else {
            Loggers.network.debug("No deep link URL found in push notification")
            return
        }
        normalizeAndBroadcast(linkString)
    }

    @objc public func handlePushOpen(response: UNNotificationResponse, authorizationStatus: UNAuthorizationStatus) {
        guard pushEnabled else {
            Loggers.event.debug("handlePushOpen skipped: pushEnabled is false")
            return
        }
        Loggers.event.debug("Handling push open (app launched from push) - Visitor ID: \(self.userIdentity.visitorId, privacy: .public), Push Token: \(self.currentPushToken, privacy: .public), Auth Status: \(authorizationStatus.stringValue, privacy: .public)")
        ATTNLaunchManager.shared.launchedFromPush = true
        let userInfo = response.notification.request.content.userInfo
        Loggers.event.debug("Push notification payload: \(userInfo, privacy: .public)")
        let callbackData = (userInfo["attentiveCallbackData"] as? [String: Any]) ?? [:]
        let escapedData = escapeJSONDictionary(callbackData)
        Loggers.event.debug("Escaped attentiveCallbackData for handlePushOpen: \(escapedData, privacy: .public)")

        // app launch event
        let alEvent: [String: Any] = [
            "ist": "al",
            "data": escapedData
        ]
        // app open from push event
        let oEvent: [String: Any] = [
            "ist": "o",
            "data": escapedData
        ]
        registerAppEvents([alEvent, oEvent], pushToken: currentPushToken, subscriptionStatus: authorizationStatus.stringValue)

        guard let linkString = escapedData["attentive_open_action_url"] as? String else {
            Loggers.network.debug("No deep link URL found in push notification")
            return
        }
        Loggers.network.debug("Broadcasting deep link URL found in push notification: \(linkString, privacy: .public)")
        normalizeAndBroadcast(linkString)
    }

    /// If the client prefers polling instead of observing NotificationCenter, or if the NotificationCenter broadcast happens too early for listener to catch it,
    /// call this to retrieve (and clear) the pending URL.
    public func consumeDeepLink() -> URL? {
        let url = stateLock.withLock { () -> URL? in
            let snapshot = _pendingURL
            _pendingURL = nil
            return snapshot
        }
        let urlString = url?.absoluteString ?? ""
        Loggers.network.debug("Consuming pending deep link: \(urlString, privacy: .public)")
        return url
    }

    // MARK: - Private Helpers

    private func registerWithAPNsIfAuthorized() {
        // Skip UNUserNotificationCenter usage in unit tests
        if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil {
            Loggers.event.debug("Skipping handleAppDidBecomeActive during XCTest run.")
            return
        }
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            Loggers.event.debug("Notification settings: \(settings.authorizationStatus.rawValue, privacy: .public)")
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
                Loggers.event.error("Unknown UNAuthorizationStatus: \(settings.authorizationStatus.rawValue, privacy: .public)")
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

        let center = UNUserNotificationCenter.current()
        Task { [weak self] in
            guard let self else { return }
            let settings = await center.notificationSettings()
            let currentStatus = settings.authorizationStatus

            let lastStatus = UserDefaults.standard.integer(forKey: ATTNSDKConfiguration.UserDefaultsKey.lastAuthStatus)
                            UserDefaults.standard.set(currentStatus.rawValue, forKey: ATTNSDKConfiguration.UserDefaultsKey.lastAuthStatus)

                            if lastStatus != UNAuthorizationStatus.authorized.rawValue &&
                                 currentStatus == .authorized {
                                    Loggers.event.debug("Push permission became authorized. Clearing cached token and forcing APNs re-registration.")
                                    UserDefaults.standard.removeObject(forKey: ATTNSDKConfiguration.UserDefaultsKey.deviceToken)
                                    self.pushTokenStore.token = ""
                                    await MainActor.run {
                                            UIApplication.shared.registerForRemoteNotifications()
                                    }
                            }

            if currentStatus == .notDetermined {
                // Await provisional flow fully (auth & APNs register)
                await self.setupProvisionalPush()
            } else if currentStatus == .authorized {
                // Clear old token and re-register every time authorization flips to authorized
                await MainActor.run {
                    if self.currentPushToken.isEmpty {
                        Loggers.event.debug("Authorization granted after denial — forcing APNs re-registration.")
                        UserDefaults.standard.removeObject(forKey: ATTNSDKConfiguration.UserDefaultsKey.deviceToken)
                            }
                    Loggers.event.debug("Notification permission authorized. Registering for remote notifications.")
                    UIApplication.shared.registerForRemoteNotifications()
                }
            }
            let updated = await center.notificationSettings()
            await MainActor.run {
                let token = self.currentPushToken
                guard !token.isEmpty else {
                    // AppDelegate will call handleRegularOpen after token is persisted
                    Loggers.event.debug("Deferring handleRegularOpen: push token not yet available. It will be triggered later from AppDelegate after APNs registration completes.")
                    return
                }
                self.api.sendPushToken(currentPushToken, userIdentity: userIdentity, authorizationStatus: updated.authorizationStatus, callback: nil)
                self.handleRegularOpen(authorizationStatus: updated.authorizationStatus)
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
            Loggers.network.error("Failed to parse deep link URL from string: '\(trimmed, privacy: .public)' - Visitor ID: \(self.userIdentity.visitorId, privacy: .public)")
            return
        }

        stateLock.withLock { _pendingURL = validURL }
        Loggers.network.debug("Broadcasting ATTNSDKDeepLinkReceived with URL: \(validURL, privacy: .public)")
        NotificationCenter.default.post(
            name: .ATTNSDKDeepLinkReceived,
            object: nil,
            userInfo: ["attentivePushDeeplinkUrl": validURL]
        )
        Loggers.network.debug("Deep link notification posted successfully - URL: \(validURL, privacy: .public)")
    }

    private func setupProvisionalPush() async {
        let center = UNUserNotificationCenter.current()
        do {
            // Grants .provisional without showing the system prompt.
            _ = try await center.requestAuthorization(options: [.alert, .sound, .badge, .provisional])
        } catch {
            Loggers.event.error("Failed to request provisional push authorization: \(error, privacy: .public)")
        }
        await MainActor.run {
            UIApplication.shared.registerForRemoteNotifications()
        }
    }


    /// Recursively escapes quotes and slashes only in attentive_message_title and attentive_message_body fields.
    func escapeJSONDictionary(_ dictionary: [String: Any]) -> [String: Any] {
        var escapedDict: [String: Any] = [:]

        for (key, value) in dictionary {
            if let strValue = value as? String {
                if key == "attentive_message_title" || key == "attentive_message_body" {
                        escapedDict[key] = strValue
                } else {
                    escapedDict[key] = strValue
                }
            } else if let nestedDict = value as? [String: Any] {
                escapedDict[key] = escapeJSONDictionary(nestedDict) // recursive for nested dicts
            } else if let arrayValue = value as? [Any] {
                escapedDict[key] = escapeJSONArray(arrayValue) // handle arrays
            } else {
                escapedDict[key] = value // leave numbers, bools, etc.
            }
        }
        return escapedDict
    }

    /// Recursively processes JSON arrays, escaping only attentive_message_title and attentive_message_body in nested dictionaries.
    func escapeJSONArray(_ array: [Any]) -> [Any] {
        return array.map { value in
            if let dictValue = value as? [String: Any] {
                return escapeJSONDictionary(dictValue)
            }
            if let nestedArray = value as? [Any] {
                return escapeJSONArray(nestedArray)
            }
            return value
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

// MARK: - PushToken storage
private final class PushTokenStore {
    private let key = ATTNSDKConfiguration.UserDefaultsKey.deviceToken
    private let queue = DispatchQueue(label: "com.attentive.sdk.PushTokenStore", qos: .userInitiated)
    private var inMemory: String?

    var token: String {
        get {
            queue.sync {
                if let token = inMemory, !token.isEmpty { return token }
                let persisted = UserDefaults.standard.string(forKey: key) ?? ""
                inMemory = persisted
                return persisted
            }
        }
        set {
            queue.sync {
                self.inMemory = newValue
                UserDefaults.standard.set(newValue, forKey: self.key)
            }
        }
    }
}

// MARK: Internal Helpers
extension ATTNSDK {
    convenience init(domain: String, mode: ATTNSDKMode, urlBuilder: ATTNCreativeUrlProviding) {
        self.init(domain: domain, mode: mode)
        self.webViewHandler = ATTNWebViewHandler(webViewProvider: self, creativeUrlBuilder: urlBuilder)
    }

    convenience init(api: ATTNAPIProtocol, urlBuilder: ATTNCreativeUrlProviding? = nil, pushEnabled: Bool = true) {
        self.init(domain: api.domain, mode: .production, pushEnabled: pushEnabled)
        self.api = api
        guard let urlBuilder = urlBuilder else { return }
        self.webViewHandler = ATTNWebViewHandler(webViewProvider: self, creativeUrlBuilder: urlBuilder)
    }
}

