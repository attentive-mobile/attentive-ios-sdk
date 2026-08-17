//
//  ATTNUserIdentity.swift
//  attentive-ios-sdk-framework
//
//  Created by Vladimir - Work on 2024-05-29.
//

import Foundation

@objc(ATTNUserIdentity)
public final class ATTNUserIdentity: NSObject {
    private let lock = NSLock()
    private var _identifiers: [String: Any]
    private var _visitorId: String
    private let visitorService: ATTNVisitorService

    @objc public var identifiers: [String: Any] {
        get { lock.withLock { _identifiers } }
        set {
            if !newValue.isEmpty {
                validate(identifiers: newValue)
            }
            lock.withLock { _identifiers = newValue }
        }
    }

    @objc public var visitorId: String {
        lock.withLock { _visitorId }
    }

    @objc
    override public convenience init() {
        self.init(identifiers: [:])
    }

    @objc(initWithIdentifiers:)
    public convenience init(identifiers: [String: Any]) {
        self.init(identifiers: identifiers, visitorService: .init())
    }

    init(identifiers: [String: Any], visitorService: ATTNVisitorService) {
        self.visitorService = visitorService
        self._identifiers = identifiers
        self._visitorId = visitorService.getVisitorId()
        super.init()
    }

    @objc
    public func clearUser() {
        // Keep visitor-id generation inside the lock so the UserDefaults write
        // order matches the in-memory swap order. If two threads race here and
        // we generate outside the lock, the last write to disk could disagree
        // with the last value of `_visitorId`, leaving the next app launch with
        // a stale visitor id. Logging stays outside: os_log latency is
        // unbounded, and holding the lock across it stalls every other
        // identity call on other threads.
        let newVisitorId = lock.withLock { () -> String in
            _identifiers = [:]
            let id = visitorService.createNewVisitorId()
            _visitorId = id
            return id
        }
        visitorService.logNewVisitorId(newVisitorId)
    }

    /// Atomic "clear only if there is something to clear." Returns `true` when the identifier
    /// store was non-empty and has now been reset (a new visitor id is rotated in), `false`
    /// when the store was already empty and no mutation happened.
    ///
    /// Callers use the return value to decide whether to fire `/user-update`. Deciding and
    /// mutating under one lock acquisition means two threads racing on the same "clear an
    /// already-anonymous device" call collapse to one server hit instead of two. See MSDK-469.
    @objc
    public func clearUserIfNeeded() -> Bool {
        let newVisitorId: String? = lock.withLock { () -> String? in
            guard !_identifiers.isEmpty else { return nil }
            _identifiers = [:]
            let id = visitorService.createNewVisitorId()
            _visitorId = id
            return id
        }
        guard let id = newVisitorId else { return false }
        visitorService.logNewVisitorId(id)
        return true
    }

    /// Atomic "switch identity only if it differs from the stored one." Returns `true` when
    /// the identifier store was replaced with `[email, phone]` (nils dropped) and a new
    /// visitor id was rotated in, `false` when the store already held exactly that set and
    /// nothing happened.
    ///
    /// Comparison is exact — no case folding, no phone normalization. Any stored identifier
    /// beyond `email`/`phone` (e.g. `clientUserId`, `customIdentifiers`) makes the two sets
    /// unequal, so the switch runs and those extra identifiers are dropped — matching the
    /// pre-MSDK-469 behavior of `clearUser` + `mergeIdentifiers`. See MSDK-469.
    @objc
    public func switchIdentity(email: String?, phone: String?) -> Bool {
        let newVisitorId: String? = lock.withLock { () -> String? in
            let matchesEmail = email == nil
                ? _identifiers[ATTNIdentifierType.email] == nil
                : (_identifiers[ATTNIdentifierType.email] as? String) == email
            let matchesPhone = phone == nil
                ? _identifiers[ATTNIdentifierType.phone] == nil
                : (_identifiers[ATTNIdentifierType.phone] as? String) == phone
            let expectedCount = (email != nil ? 1 : 0) + (phone != nil ? 1 : 0)
            if matchesEmail && matchesPhone && _identifiers.count == expectedCount {
                return nil
            }
            var replacement: [String: Any] = [:]
            if let email = email { replacement[ATTNIdentifierType.email] = email }
            if let phone = phone { replacement[ATTNIdentifierType.phone] = phone }
            _identifiers = replacement
            let id = visitorService.createNewVisitorId()
            _visitorId = id
            return id
        }
        guard let id = newVisitorId else { return false }
        visitorService.logNewVisitorId(id)
        return true
    }

    @objc
    public func mergeIdentifiers(_ newIdentifiers: [String: Any]) {
        validate(identifiers: newIdentifiers)
        lock.withLock {
            // In case of a key conflict, the new value from newIdentifiers should be used.
            _identifiers.merge(newIdentifiers) { (_, new) in new }
        }
    }
}

fileprivate extension ATTNUserIdentity {
    func validate(identifiers: [String: Any]) {
        for key in identifiers.keys {
            if key == ATTNIdentifierType.customIdentifiers {
                ATTNParameterValidation.verify1DStringDictionaryOrNil(
                    identifiers[key] as? NSDictionary,
                    inputName: key)
            } else {
                ATTNParameterValidation.verifyStringOrNil(
                    identifiers[key] as? NSObject,
                    inputName: key)
            }
        }
    }
}
