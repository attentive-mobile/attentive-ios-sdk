//
//  ATTNSDK+MarketingSubscriptions.swift
//  attentive-ios-sdk-framework
//

import Foundation

// MARK: - Marketing Subscriptions
extension ATTNSDK {

    /// Opts the user into email/SMS (a.k.a. non-push) marketing subscriptions.
    ///
    /// - For push-enabled clients (`pushEnabled == true`): if no push token is yet available,
    ///   the request is queued and flushed once the token registers. This preserves the
    ///   existing flow where opt-in is associated with the device's push token.
    /// - For non-push clients (`pushEnabled == false`): there will never be a push token,
    ///   so the request is sent immediately without one.
    @objc(optInMarketingSubscriptionWithEmail:phone:callback:)
    public func optInMarketingSubscription(
        email: String? = nil,
        phone: String? = nil,
        callback: ATTNAPICallback? = nil
    ) {
        let email = normalizeContactValue(email)
        let phone = normalizeContactValue(phone)

        guard email != nil || phone != nil else {
            Loggers.event.error("Opt-in failed: missing both email and phone number - Visitor ID: \(self.userIdentity.visitorId, privacy: .public), Push Token: \(self.currentPushToken, privacy: .public)")
            callback?(nil, nil, nil, ATTNError.missingContactInfo)
            return
        }

        let token = currentPushToken
        if pushEnabled && token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            enqueueMarketingRequest(.init(
                kind: .optIn,
                email: email,
                phone: phone,
                callback: callback,
                createdAt: Date()
            ))
            return
        }

        Loggers.event.debug("Processing opt-in marketing subscription - Visitor ID: \(self.userIdentity.visitorId, privacy: .public), Push Token: \(self.currentPushToken, privacy: .public), Email: \(email ?? "nil", privacy: .public), Phone: \(phone ?? "nil", privacy: .public)")

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

    /// Opts the user out of email/SMS (a.k.a. non-push) marketing subscriptions.
    ///
    /// Same push-token semantics as ``optInMarketingSubscription(email:phone:callback:)``:
    /// push-enabled clients queue until a token arrives; non-push clients send immediately
    /// without one.
    @objc(optOutMarketingSubscriptionWithEmail:phone:callback:)
    public func optOutMarketingSubscription(
        email: String? = nil,
        phone: String? = nil,
        callback: ATTNAPICallback? = nil
    ) {
        let email = normalizeContactValue(email)
        let phone = normalizeContactValue(phone)

        guard email != nil || phone != nil else {
            Loggers.event.error("Opt-out failed: missing both email and phone number - Visitor ID: \(self.userIdentity.visitorId, privacy: .public), Push Token: \(self.currentPushToken, privacy: .public)")
            callback?(nil, nil, nil, ATTNError.missingContactInfo)
            return
        }

        let token = currentPushToken
        if pushEnabled && token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            enqueueMarketingRequest(.init(
                kind: .optOut,
                email: email,
                phone: phone,
                callback: callback,
                createdAt: Date()
            ))
            return
        }

        Loggers.event.debug("Processing opt-out marketing subscription - Visitor ID: \(self.userIdentity.visitorId, privacy: .public), Push Token: \(self.currentPushToken, privacy: .public), Email: \(email ?? "nil", privacy: .public), Phone: \(phone ?? "nil", privacy: .public)")

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

    /// Switches the current user identity by associating the device with new email and/or phone identifiers.
    ///
    /// This method:
    /// 1. Clears all existing identifiers and generates a new anonymous visitor ID (same as `clearUser()`).
    /// 2. Sends the new email/phone to the server, which re-identifies the device under the new user.
    ///
    /// At least one of `email` or `phone` must be provided.
    ///
    /// - Parameters:
    ///   - email: The new user's email address (optional if phone is provided).
    ///   - phone: The new user's phone number in E.164 format (optional if email is provided).
    ///   - callback: Called when the server responds. `nil` is acceptable.
    @objc(updateUserWithEmail:phone:callback:)
    public func updateUser(email: String? = nil,
                                                 phone: String? = nil,
                                                 callback: ATTNAPICallback? = nil) {
        Loggers.event.debug("updateUser: switching user identity - Current Visitor ID: \(self.userIdentity.visitorId, privacy: .public), Email: \(email ?? "nil", privacy: .public), Phone: \(phone ?? "nil", privacy: .public)")
        let trimmedPushToken = currentPushToken.trimmingCharacters(in: .whitespacesAndNewlines)
        let pushToken = !trimmedPushToken.isEmpty
        ? trimmedPushToken
        : (UserDefaults.standard.string(forKey: ATTNSDKConfiguration.UserDefaultsKey.deviceToken) ?? "")
        guard !pushToken.isEmpty else {
            Loggers.event.error("updateUser: aborted — missing push token - Tried in-memory token: '\(trimmedPushToken, privacy: .public)', Tried UserDefaults: '\(UserDefaults.standard.string(forKey: ATTNSDKConfiguration.UserDefaultsKey.deviceToken) ?? "nil", privacy: .public)', Visitor ID: \(self.userIdentity.visitorId, privacy: .public)")
            callback?(nil, nil, nil, ATTNSDKError.missingPushToken)
            return
        }
        Loggers.event.debug("updateUser: proceeding with push token: \(pushToken, privacy: .public)")
        clearUserIdentifiers()
        var newIdentifiers: [String: Any] = [:]
        if let email = email { newIdentifiers[ATTNIdentifierType.email] = email }
        if let phone = phone { newIdentifiers[ATTNIdentifierType.phone] = phone }
        userIdentity.mergeIdentifiers(newIdentifiers)
        api.updateUser(
            pushToken: pushToken,
            userIdentity: userIdentity,
            email: email,
            phone: phone,
            operationContext: "updateUser",
            callback: callback
        )
    }

    // MARK: - Marketing Queue Management

    func flushPendingMarketingRequests(with token: String) {
        marketingQueue.async { [weak self] in
            guard let self else { return }
            let now = Date()
            let (valid, expired) = self.pendingMarketingRequests.partitioned { now.timeIntervalSince($0.createdAt) <= self.pendingMarketingTTL }
            self.pendingMarketingRequests = []
            self.cancelMarketingExpiryTimerIfNeeded()

            for request in expired {
                Loggers.event.error("Marketing request expired before push token became available - Kind: \(request.kind.rawValue, privacy: .public)")
                request.callback?(nil, nil, nil, ATTNSDKError.missingPushToken)
            }

            for request in valid {
                self.sendMarketingRequest(request, pushToken: token)
            }
        }
    }

    // MARK: - Private Helpers

    private func normalizeContactValue(_ value: String?) -> String? {
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines)
        return (trimmed?.isEmpty == false) ? trimmed : nil
    }

    private func enqueueMarketingRequest(_ request: PendingMarketingRequest) {
        marketingQueue.async { [weak self] in
            guard let self else { return }
            let expiresAt = request.createdAt.addingTimeInterval(self.pendingMarketingTTL)
            Loggers.event.debug("Queueing marketing request until push token is available - Kind: \(request.kind.rawValue, privacy: .public), Expires: \(expiresAt, privacy: .public)")
            self.pendingMarketingRequests.append(request)
            self.scheduleMarketingExpiryTimer()
        }
    }

    private func scheduleMarketingExpiryTimer() {
        guard !pendingMarketingRequests.isEmpty else {
            cancelMarketingExpiryTimerIfNeeded()
            return
        }
        let nextExpiry = pendingMarketingRequests
            .map { $0.createdAt.addingTimeInterval(pendingMarketingTTL) }
            .min() ?? Date().addingTimeInterval(pendingMarketingTTL)
        let delay = max(0, nextExpiry.timeIntervalSinceNow)
        cancelMarketingExpiryTimerIfNeeded()
        let timer = DispatchSource.makeTimerSource(queue: marketingQueue)
        timer.schedule(deadline: .now() + delay, repeating: .never)
        timer.setEventHandler { [weak self] in
            self?.expirePendingMarketingRequests()
        }
        pendingMarketingExpiryTimer = timer
        timer.resume()
    }

    private func cancelMarketingExpiryTimerIfNeeded() {
        pendingMarketingExpiryTimer?.cancel()
        pendingMarketingExpiryTimer = nil
    }

    private func expirePendingMarketingRequests() {
        let now = Date()
        let (valid, expired) = pendingMarketingRequests.partitioned { now.timeIntervalSince($0.createdAt) <= pendingMarketingTTL }
        pendingMarketingRequests = valid
        scheduleMarketingExpiryTimer()
        for request in expired {
            Loggers.event.error("Marketing request expired before push token became available - Kind: \(request.kind.rawValue, privacy: .public)")
            request.callback?(nil, nil, nil, ATTNSDKError.missingPushToken)
        }
    }

    private func sendMarketingRequest(_ request: PendingMarketingRequest, pushToken: String) {
        switch request.kind {
        case .optIn:
            Loggers.event.debug("Sending queued opt-in marketing subscription - Push Token: \(pushToken, privacy: .public), Email: \(request.email ?? "nil", privacy: .public), Phone: \(request.phone ?? "nil", privacy: .public)")
            api.sendOptInMarketingSubscription(
                pushToken: pushToken,
                email: request.email,
                phone: request.phone,
                userIdentity: userIdentity,
                callback: request.callback
            )
        case .optOut:
            Loggers.event.debug("Sending queued opt-out marketing subscription - Push Token: \(pushToken, privacy: .public), Email: \(request.email ?? "nil", privacy: .public), Phone: \(request.phone ?? "nil", privacy: .public)")
            api.sendOptOutMarketingSubscription(
                pushToken: pushToken,
                email: request.email,
                phone: request.phone,
                userIdentity: userIdentity,
                callback: request.callback
            )
        }
    }
}

// MARK: - Supporting Types

struct PendingMarketingRequest {
    enum Kind: String {
        case optIn
        case optOut
    }

    let kind: Kind
    let email: String?
    let phone: String?
    let callback: ATTNAPICallback?
    let createdAt: Date
}

extension Array {
    func partitioned(by isIncluded: (Element) -> Bool) -> ([Element], [Element]) {
        var included: [Element] = []
        var excluded: [Element] = []
        included.reserveCapacity(count)
        excluded.reserveCapacity(count)
        for element in self {
            if isIncluded(element) {
                included.append(element)
            } else {
                excluded.append(element)
            }
        }
        return (included, excluded)
    }
}
