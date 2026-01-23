//
//  ATTNSDK.swift
//  attentive-ios-sdk-framework
//
//  Created by Vladimir - Work on 2024-05-27.
//

import Foundation
import WebKit
import UserNotifications

public typealias ATTNCreativeTriggerCompletionHandler = (String) -> Void

extension Notification.Name {
    static let didReceivePushOpen = Notification.Name("ATTNSDKDidReceivePushOpen")
}

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
    /// Holds exactly one pending deep-link URL (new taps overwrite old).
    private var pendingURL: URL?
    // Debounce mechanism to prevent duplicate events
    private var lastRegularOpenTime: Date?

    // Single accessor used across the SDK
    private var currentPushToken: String { pushTokenStore.token }

    // MARK: Instance Properties
    var parentView: UIView?
    var triggerHandler: ATTNCreativeTriggerCompletionHandler?
    var webView: WKWebView?

    private(set) var api: ATTNAPIProtocol
    private(set) var userIdentity: ATTNUserIdentity

    internal var domain: String
    private var mode: ATTNSDKMode
    private var webViewHandler: ATTNWebViewHandling?

    /// Determinates if fatigue rules evaluation will be skipped for Creative. Default value is false.
    @objc public var skipFatigueOnCreative: Bool = false

    public init(domain: String, mode: ATTNSDKMode) {
        Loggers.creative.debug("Initializing ATTNSDK v\(ATTNConstants.sdkVersion, privacy: .public), Mode: \(mode.rawValue, privacy: .public), Domain: \(domain, privacy: .public)")

        self.domain = domain
        self.mode = mode

        self.userIdentity = .init()
        self.api = ATTNAPI(domain: domain)

        super.init()

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

        Loggers.creative.debug("ATTNSDK initialization successful - Visitor ID: \(self.userIdentity.visitorId, privacy: .public), Domain: \(domain, privacy: .public)")
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

    /// Async initializer that reports success/failure after background setup.
    public static func initialize(
        domain: String,
        mode: ATTNSDKMode = .production,
        completion: @escaping (Result<ATTNSDK, Error>) -> Void) {
            let sdk = ATTNSDK(domain: domain, mode: mode)
            DispatchQueue.global(qos: .userInitiated).async {
                let setupSucceeded = sdk.webViewHandler != nil
                DispatchQueue.main.async {
                    if setupSucceeded {
                        Loggers.creative.debug("ATTNSDK async initialization successful - Visitor ID: \(sdk.userIdentity.visitorId, privacy: .public)")
                        completion(.success(sdk))
                    } else {
                        Loggers.creative.error("ATTNSDK async initialization failed - webViewHandler setup unsuccessful")
                        completion(.failure(ATTNSDKError.initializationFailed))
                    }
                }
            }
        }

    // MARK: Public API
    @objc(identify:)
    public func identify(_ userIdentifiers: [String: Any]) {
        Loggers.event.debug("Identifying user - Visitor ID: \(self.userIdentity.visitorId), Identifiers: \(userIdentifiers)")
        userIdentity.mergeIdentifiers(userIdentifiers)
        api.send(userIdentity: userIdentity)
        Loggers.event.debug("User identity sent successfully - Visitor ID: \(self.userIdentity.visitorId)")
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
        let oldVisitorId = userIdentity.visitorId
        userIdentity.clearUser()
        Loggers.creative.debug("User cleared successfully - Old Visitor ID: \(oldVisitorId, privacy: .public), New Visitor ID: \(self.userIdentity.visitorId, privacy: .public)")
    }

    @objc(updateDomain:)
    public func update(domain: String) {
        guard self.domain != domain else {
            Loggers.creative.debug("Domain update skipped - requested domain matches current domain: \(domain)")
            return
        }
        let oldDomain = self.domain
        self.domain = domain
        api.update(domain: domain)
        Loggers.creative.debug("Domain updated successfully - Old Domain: \(oldDomain), New Domain: \(domain), Visitor ID: \(self.userIdentity.visitorId)")
        api.send(userIdentity: userIdentity)
        Loggers.creative.debug("Identity event sent with new domain - Domain: \(domain), Visitor ID: \(self.userIdentity.visitorId)")
    }

    // MARK: Push Permissions & Token

    /// Ask the user for push‐notification permission and register with APNs if granted.
    @objc(registerForPushNotificationsWithCompletion:)
    public func registerForPushNotifications(completion: ((Bool, Error?) -> Void)? = nil) {
        Loggers.event.debug("Requesting push-notification authorization…")
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
            if granted {
                self?.registerWithAPNsIfAuthorized()
            }
            completion?(granted, error)
        }
    }

    @objc(registerDeviceToken:authorizationStatus:callback:)
    public func registerDeviceToken(_ deviceToken: Data, authorizationStatus: UNAuthorizationStatus, callback: ATTNAPICallback? = nil
    ) {
        let tokenString = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
        Loggers.event.debug("Registering device token - Visitor ID: \(self.userIdentity.visitorId), Push Token: \(tokenString), Auth Status: \(authorizationStatus.stringValue)")
        pushTokenStore.token = tokenString
        // this is called after events are sent. we need a better way to persist this
        api.sendPushToken(tokenString, userIdentity: userIdentity, authorizationStatus: authorizationStatus) { data, url, response, error in
            Loggers.event.debug("----- Push-Token Request Result -----")
            if let url = url {
                Loggers.event.debug("Request URL: \(url.absoluteString)")
            }
            if let http = response as? HTTPURLResponse {
                Loggers.event.debug("Status Code: \(http.statusCode)")
                Loggers.event.debug("Headers: \(http.allHeaderFields)")
                if http.statusCode >= 200 && http.statusCode < 300 {
                    Loggers.event.debug("Device token registration successful - Push Token: \(tokenString)")
                } else if http.statusCode >= 400 {
                    Loggers.event.error("Device token registration failed with status code: \(http.statusCode)")
                }
            }
            if let d = data, let body = String(data: d, encoding: .utf8) {
                Loggers.event.debug("Response Body:\n\(body)")
            }
            if let error = error {
                Loggers.event.error("Device token registration error: \(error.localizedDescription)")
            }

            callback?(data, url, response, error)
        }
    }

    @objc(registerForPushFailed:)
    public func failedToRegisterForPush(_ error: Error) {
        Loggers.event.error("Failed to register for remote notifications: \(error.localizedDescription)")
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
            Loggers.event.error("registerAppEvents aborted: missing push token - Visitor ID: \(self.userIdentity.visitorId)")
            callback?(nil, nil, nil, ATTNSDKError.missingPushToken)
            return
        }
        Loggers.event.debug("Registering app events - Visitor ID: \(self.userIdentity.visitorId), Push Token: \(pushToken), Subscription Status: \(subscriptionStatus), Event Count: \(events.count)")
        api.sendAppEvents(pushToken: pushToken, subscriptionStatus: subscriptionStatus, transport: transport, events: events, userIdentity: userIdentity) { data, url, response, error in
            Loggers.event.debug("----- App Open Events Request Result -----")
            if let url = url {
                Loggers.event.debug("Request URL: \(url.absoluteString)")
            }
            if let http = response as? HTTPURLResponse {
                Loggers.event.debug("Status Code: \(http.statusCode)")
                Loggers.event.debug("Headers: \(http.allHeaderFields)")
                if http.statusCode >= 200 && http.statusCode < 300 {
                    Loggers.event.debug("App events sent successfully")
                } else if http.statusCode >= 400 {
                    Loggers.event.error("App events failed with status code: \(http.statusCode)")
                }
            }
            if let d = data, let body = String(data: d, encoding: .utf8) {
                Loggers.event.debug("Response Body:\n\(body)")
            }
            if let error = error {
                Loggers.event.error("App events error: \(error.localizedDescription)")
            }

            callback?(data, url, response, error)
        }
    }

    @objc public func handleRegularOpen(pushToken: String? = nil, authorizationStatus: UNAuthorizationStatus) {
        Loggers.event.debug("Handling regular app open - Visitor ID: \(self.userIdentity.visitorId), Push Token: \(self.currentPushToken), Auth Status: \(authorizationStatus.stringValue)")

        // checks and resets push launch flag
        guard !ATTNLaunchManager.shared.resetPushLaunchFlag() else {
            Loggers.event.debug("Skipping regular open handler as push launch flag is set to true")
            return
        }
        // debounce to remove duplicate events; only allow app events tracking once every 2 seconds
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
        registerAppEvents([alEvent], pushToken: currentPushToken, subscriptionStatus: authorizationStatus.stringValue)
    }

    @objc public func handleForegroundPush(response: UNNotificationResponse, authorizationStatus: UNAuthorizationStatus) {
        Loggers.event.debug("Handling foreground push notification - Visitor ID: \(self.userIdentity.visitorId), Push Token: \(self.currentPushToken), Auth Status: \(authorizationStatus.stringValue)")
        let userInfo = response.notification.request.content.userInfo
        Loggers.event.debug("Push notification payload: \(userInfo)")
        let callbackData = (userInfo["attentiveCallbackData"] as? [String: Any]) ?? [:]
        let escapedData = escapeJSONDictionary(callbackData)
        Loggers.event.debug("Escaped attentiveCallbackData for handleForegroundPush: \(escapedData)")
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
        Loggers.event.debug("Handling push open (app launched from push) - Visitor ID: \(self.userIdentity.visitorId), Push Token: \(self.currentPushToken), Auth Status: \(authorizationStatus.stringValue)")
        ATTNLaunchManager.shared.launchedFromPush = true
        let userInfo = response.notification.request.content.userInfo
        Loggers.event.debug("Push notification payload: \(userInfo)")
        let callbackData = (userInfo["attentiveCallbackData"] as? [String: Any]) ?? [:]
        let escapedData = escapeJSONDictionary(callbackData)
        Loggers.event.debug("Escaped attentiveCallbackData for handlePushOpen: \(escapedData)")

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

    // MARK: Marketing Subscriptions

    @objc(optInMarketingSubscriptionWithEmail:phone:callback:)
    public func optInMarketingSubscription(
        email: String? = nil,
        phone: String? = nil,
        callback: ATTNAPICallback? = nil
    ) {
        let email = normalize(email)
        let phone = normalize(phone)

        guard email != nil || phone != nil else {
            Loggers.event.error("Opt-in failed: missing both email and phone number - Visitor ID: \(self.userIdentity.visitorId), Push Token: \(self.currentPushToken)")
            callback?(nil, nil, nil, ATTNError.missingContactInfo)
            return
        }

        Loggers.event.debug("Processing opt-in marketing subscription - Visitor ID: \(self.userIdentity.visitorId), Push Token: \(self.currentPushToken), Email: \(email ?? "nil"), Phone: \(phone ?? "nil")")

        api.sendOptInMarketingSubscription(
            pushToken: currentPushToken,
            email: email,
            phone: phone,
            userIdentity: userIdentity,
            callback: callback
        )
    }

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

    @objc(optOutMarketingSubscriptionWithEmail:phone:callback:)
    public func optOutMarketingSubscription(
        email: String? = nil,
        phone: String? = nil,
        callback: ATTNAPICallback? = nil
    ) {
        let email = normalize(email)
        let phone = normalize(phone)

        guard email != nil || phone != nil else {
            Loggers.event.error("Opt-out failed: missing both email and phone number - Visitor ID: \(self.userIdentity.visitorId), Push Token: \(self.currentPushToken)")
            callback?(nil, nil, nil, ATTNError.missingContactInfo)
            return
        }

        Loggers.event.debug("Processing opt-out marketing subscription - Visitor ID: \(self.userIdentity.visitorId), Push Token: \(self.currentPushToken), Email: \(email ?? "nil"), Phone: \(phone ?? "nil")")

        api.sendOptOutMarketingSubscription(
            pushToken: currentPushToken,
            email: email,
            phone: phone,
            userIdentity: userIdentity,
            callback: callback
        )
    }

    @objc(optOutMarketingSubscriptionWithEmail:callback:)
    public func optOutMarketingSubscription(
        email: String,
        callback: ATTNAPICallback? = nil
    ) {
        optOutMarketingSubscription(email: email, phone: nil, callback: callback)
    }

    @objc(optOutMarketingSubscriptionWithPhone:callback:)
    public func optOutMarketingSubscription(
        phone: String,
        callback: ATTNAPICallback? = nil
    ) {
        optOutMarketingSubscription(email: nil, phone: phone, callback: callback)
    }

    @objc(updateUserWithEmail:phone:callback:)
    public func updateUser(email: String? = nil,
                                                 phone: String? = nil,
                                                 callback: ATTNAPICallback? = nil) {
        Loggers.event.debug("Attempting to update user - Current Visitor ID: \(self.userIdentity.visitorId), Email: \(email ?? "nil"), Phone: \(phone ?? "nil")")
        let trimmedPushToken = currentPushToken.trimmingCharacters(in: .whitespacesAndNewlines)
        let pushToken = !trimmedPushToken.isEmpty
        ? trimmedPushToken
        : (UserDefaults.standard.string(forKey: "attentiveDeviceToken") ?? "")
        guard !pushToken.isEmpty else {
            Loggers.event.error("updateUser aborted: missing push token - Tried in-memory token: '\(trimmedPushToken)', Tried UserDefaults: '\(UserDefaults.standard.string(forKey: "attentiveDeviceToken") ?? "nil")', Visitor ID: \(self.userIdentity.visitorId)")
            callback?(nil, nil, nil, ATTNSDKError.missingPushToken)
            return
        }
        Loggers.event.debug("Updating user with push token: \(pushToken)")
        clearUser()
        api.updateUser(
            pushToken: pushToken,
            userIdentity: userIdentity,
            email: email,
            phone: phone,
            callback: callback
        )
    }

    // MARK: - Private Helpers

    private func normalize(_ value: String?) -> String? {
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines)
        return (trimmed?.isEmpty == false) ? trimmed : nil
    }

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

        let center = UNUserNotificationCenter.current()
        Task { [weak self] in
            guard let self else { return }
            let settings = await center.notificationSettings()
            let currentStatus = settings.authorizationStatus

            let lastStatus = UserDefaults.standard.integer(forKey: "attentiveLastAuthStatus")
                            UserDefaults.standard.set(currentStatus.rawValue, forKey: "attentiveLastAuthStatus")

                            if lastStatus != UNAuthorizationStatus.authorized.rawValue &&
                                 currentStatus == .authorized {
                                    Loggers.event.debug("Push permission became authorized. Clearing cached token and forcing APNs re-registration.")
                                    UserDefaults.standard.removeObject(forKey: "attentiveDeviceToken")
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
                        UserDefaults.standard.removeObject(forKey: "attentiveDeviceToken")
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
            Loggers.network.error("Failed to parse deep link URL from string: '\(trimmed)' - Visitor ID: \(self.userIdentity.visitorId)")
            return
        }

        pendingURL = validURL
        Loggers.network.debug("Broadcasting ATTNSDKDeepLinkReceived with URL: \(validURL)")
        NotificationCenter.default.post(
            name: .ATTNSDKDeepLinkReceived,
            object: nil,
            userInfo: ["attentivePushDeeplinkUrl": validURL]
        )
        Loggers.network.debug("Deep link notification posted successfully - URL: \(validURL)")
    }

    private func setupProvisionalPush() async {
        let center = UNUserNotificationCenter.current()
        do {
            // Grants .provisional without showing the system prompt.
            _ = try await center.requestAuthorization(options: [.alert, .sound, .badge, .provisional])
        } catch {
            Loggers.event.error("Failed to request provisional push authorization: \(error)")
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
                }
                else {
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
            } else if let nestedArray = value as? [Any] {
                return escapeJSONArray(nestedArray)
            } else {
                return value
            }
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
    private let key = "attentiveDeviceToken"
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

    convenience init(api: ATTNAPIProtocol, urlBuilder: ATTNCreativeUrlProviding? = nil) {
        self.init(domain: api.domain)
        self.api = api
        guard let urlBuilder = urlBuilder else { return }
        self.webViewHandler = ATTNWebViewHandler(webViewProvider: self, creativeUrlBuilder: urlBuilder)
    }
}
