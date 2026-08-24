//
//  ATTNUserIdentity.swift
//  attentive-ios-sdk-framework
//
//  Created by Vladimir - Work on 2024-05-29.
//

import Foundation

/// Outcome of an `ATTNUserIdentity.planXxx` call. The MSDK-469 guards live inside those
/// primitives; this enum tells the caller what the primitive did and what still needs to
/// happen at the network layer.
enum ATTNIdentitySyncDecision {
    /// Local state already matches the request AND the last successful `/user-update`
    /// confirmed the same state on the server. Caller should skip both rotation and network.
    case skip

    /// Local state already matches the request but the last successful `/user-update` did
    /// NOT confirm this state (never synced, prior request failed, or the push token has
    /// changed). Caller should fire `/user-update` again to retry — no visitor ID rotation,
    /// no local mutation.
    case retryWithoutRotation

    /// Local state did not match the request; identifiers were replaced and visitor ID was
    /// rotated. Caller must fire `/user-update` with the new visitor ID.
    case rotatedAndReplaced
}

@objc(ATTNUserIdentity)
public final class ATTNUserIdentity: NSObject {
    private enum Constants {
        static var lastSyncedPushTokenKey: String { "lastSyncedPushToken" }
        static var lastSyncedEmailKey: String { "lastSyncedEmail" }
        static var lastSyncedPhoneKey: String { "lastSyncedPhone" }
        static var lastSyncedDomainKey: String { "lastSyncedDomain" }
    }

    private let lock = NSLock()
    private var _identifiers: [String: Any]
    private var _visitorId: String
    private let visitorService: ATTNVisitorService
    private let persistentStorage: ATTNPersistentStorageProtocol

    // Sync state — records what the last successful /user-update told the server, so the
    // MSDK-469 guards can distinguish "no change to send" (skip) from "local matches but
    // server hasn't confirmed" (retry). All access is behind `lock`. Persisted across app
    // launches so a relaunch after a failed /user-update still retries on the next call.
    private var _lastSyncedPushToken: String?
    private var _lastSyncedEmail: String?
    private var _lastSyncedPhone: String?
    // Domain is part of the sync record because `ATTNSDK.updateDomain(...)` can change the
    // Attentive company this device reports to at runtime. Without it, a sync record confirmed
    // against the old company would let `planUpdateUser` / `planClearUser` return `.skip` for
    // a call the new company's backend has never seen — matching what the Android SDK now
    // guards against in the counterpart PR (MSDK-470).
    private var _lastSyncedDomain: String?

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
        self.init(identifiers: identifiers, visitorService: .init(), persistentStorage: ATTNPersistentStorage())
    }

    init(
        identifiers: [String: Any],
        visitorService: ATTNVisitorService,
        persistentStorage: ATTNPersistentStorageProtocol = ATTNPersistentStorage()
    ) {
        self.visitorService = visitorService
        self.persistentStorage = persistentStorage
        self._identifiers = identifiers
        self._visitorId = visitorService.getVisitorId()
        // Load sync state before super.init returns so the very first plan* call after
        // construction sees the persisted record. A failed prior /user-update whose app
        // was killed before the callback fired will show up here as "sync != local" and
        // the next call will retry.
        self._lastSyncedPushToken = persistentStorage.readString(forKey: Constants.lastSyncedPushTokenKey)
        self._lastSyncedEmail = persistentStorage.readString(forKey: Constants.lastSyncedEmailKey)
        self._lastSyncedPhone = persistentStorage.readString(forKey: Constants.lastSyncedPhoneKey)
        self._lastSyncedDomain = persistentStorage.readString(forKey: Constants.lastSyncedDomainKey)
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

    @objc
    public func mergeIdentifiers(_ newIdentifiers: [String: Any]) {
        validate(identifiers: newIdentifiers)
        lock.withLock {
            // In case of a key conflict, the new value from newIdentifiers should be used.
            _identifiers.merge(newIdentifiers) { (_, new) in new }
        }
    }

    // MARK: - MSDK-469 sync-aware guards
    //
    // These primitives combine three questions into one atomic decision under the identity
    // lock: (1) does local state already reflect the request, (2) did the last successful
    // /user-update confirm this state on the server, and (3) does the guard let us skip
    // some work? Deciding all three under one lock acquisition means concurrent same-state
    // calls collapse to one server hit (the first mutator wins; the rest see the mutated
    // state and skip). Guarding on server-confirmed state — not just local equality —
    // means a failed /user-update naturally retries on the next call, and a relaunch
    // after a prior failure detaches the push token instead of leaving it attached.

    /// Decides what `updateUser(email:phone:)` should do given the current local state, the
    /// last-successfully-synced state, the current push token, and the current domain.
    ///
    /// - Returns: `.skip` when the incoming pair equals both local state AND the last
    ///   confirmed sync (for the same push token and domain); the caller can skip
    ///   everything. `.retryWithoutRotation` when local already matches but the server
    ///   hasn't confirmed the same state; caller should fire `/user-update` again without
    ///   rotating. `.rotatedAndReplaced` when local differed and was replaced; caller must
    ///   fire `/user-update` with the new visitor id.
    ///
    /// Cold-launch note: `_identifiers` is in-memory only (email/phone are not persisted),
    /// so a launch-time `updateUser(E, P)` starts from `_identifiers == {}` and would
    /// mismatch every time — rotating the visitor id and POSTing on every cold launch,
    /// which is the exact regression MSDK-469 exists to stop. When the persisted sync
    /// record shows the server has already confirmed the same `(E, P, pushToken, domain)`
    /// tuple, we adopt those identifiers into `_identifiers` locally without rotating and
    /// return `.skip`. This mirrors the Android SDK's `hasNoUserScopedIdentifiers` branch
    /// in `planUpdateUser` (MSDK-470).
    func planUpdateUser(email: String?, phone: String?, pushToken: String, domain: String) -> ATTNIdentitySyncDecision {
        // Match ATTNAPI.updateUser's contract: it strips whitespace and drops empty values
        // before sending. If we compared raw inputs against the normalized `_lastSynced*`
        // values, "  a@b.com  " and "a@b.com" would look different here even though the
        // server has already recorded them as identical — causing a spurious retry.
        let normalizedEmail = Self.normalizeContact(email)
        let normalizedPhone = Self.normalizeContact(phone)

        // Decide + mutate + read sync record all under one lock acquisition. Two threads
        // racing on the same-identity call see a coherent snapshot: the first mutator
        // wins, the rest observe the mutated state and return skip/retry.
        enum Outcome {
            case mutated(newVisitorId: String)
            case localMatchesAndSynced
            case localMatchesButUnsynced
            case adoptedFromSyncRecord
        }
        let outcome: Outcome = lock.withLock { () -> Outcome in
            let hasNoUserScopedIdentifiers = _identifiers.isEmpty
            let syncMatches = isSyncRecordMatchingLocked(
                email: normalizedEmail,
                phone: normalizedPhone,
                pushToken: pushToken,
                domain: domain
            )
            // Cold-launch adoption: local has no user-scoped identifiers (a process
            // restart cleared the in-memory dict) but the persisted sync record already
            // reflects this exact pair for the current push token AND domain. Adopt the
            // pair into `_identifiers` without rotating so the very next call inside this
            // process sees the identifiers as "match" and returns `.skip` cleanly.
            if hasNoUserScopedIdentifiers && syncMatches {
                if let email = normalizedEmail { _identifiers[ATTNIdentifierType.email] = email }
                if let phone = normalizedPhone { _identifiers[ATTNIdentifierType.phone] = phone }
                return .adoptedFromSyncRecord
            }
            if !identifiersMatchLocked(email: normalizedEmail, phone: normalizedPhone) {
                var replacement: [String: Any] = [:]
                if let email = normalizedEmail { replacement[ATTNIdentifierType.email] = email }
                if let phone = normalizedPhone { replacement[ATTNIdentifierType.phone] = phone }
                _identifiers = replacement
                let id = visitorService.createNewVisitorId()
                _visitorId = id
                return .mutated(newVisitorId: id)
            }
            return syncMatches ? .localMatchesAndSynced : .localMatchesButUnsynced
        }
        switch outcome {
        case .mutated(let newVisitorId):
            visitorService.logNewVisitorId(newVisitorId)
            return .rotatedAndReplaced
        case .localMatchesAndSynced, .adoptedFromSyncRecord:
            return .skip
        case .localMatchesButUnsynced:
            return .retryWithoutRotation
        }
    }

    /// Decides what `clearUser()` should do given the current push token and domain.
    ///
    /// - Returns: `.skip` when local is already empty AND the last confirmed sync (for the
    ///   same push token and domain) recorded an empty state; caller can skip everything.
    ///   `.retryWithoutRotation` when local is empty but the sync record shows non-empty
    ///   (or a different push token, a different domain, or no record at all with a push
    ///   token present); caller should fire `/user-update` with empty email/phone to
    ///   detach the token. `.rotatedAndReplaced` when local was non-empty and has been
    ///   cleared; caller must fire `/user-update` with the new visitor id.
    func planClearUser(pushToken: String, domain: String) -> ATTNIdentitySyncDecision {
        enum Outcome {
            case mutated(newVisitorId: String)
            case alreadyEmptyAndSynced
            case alreadyEmptyButUnsynced
        }
        let outcome: Outcome = lock.withLock { () -> Outcome in
            if !_identifiers.isEmpty {
                _identifiers = [:]
                let id = visitorService.createNewVisitorId()
                _visitorId = id
                return .mutated(newVisitorId: id)
            }
            // Local is empty. Skip only when the sync record confirms server sees empty
            // for THIS push token AND THIS domain. Every other case — no record yet,
            // different push token on record (APNs rotated), different domain (host called
            // updateDomain), or a non-empty pair on record (previous detach never
            // succeeded) — must retry the detach.
            return isSyncRecordMatchingLocked(email: nil, phone: nil, pushToken: pushToken, domain: domain)
                ? .alreadyEmptyAndSynced
                : .alreadyEmptyButUnsynced
        }
        switch outcome {
        case .mutated(let newVisitorId):
            visitorService.logNewVisitorId(newVisitorId)
            return .rotatedAndReplaced
        case .alreadyEmptyAndSynced:
            return .skip
        case .alreadyEmptyButUnsynced:
            return .retryWithoutRotation
        }
    }

    /// Called from the `/user-update` completion when the request succeeded (HTTP 2xx,
    /// no transport error). Records the tuple the server confirmed — email, phone, push
    /// token, and domain — so the next `planUpdateUser` / `planClearUser` can distinguish
    /// "already synced" from "needs retry". Persisted so a relaunch preserves the
    /// confirmation.
    ///
    /// Nil email/phone are stored as absence — matching what the server actually sees when
    /// clearUser posts an empty `m: {}` — so a subsequent clearUser with an empty local
    /// state correctly resolves to `.skip`. Domain is stored because host apps can call
    /// `ATTNSDK.updateDomain(...)` at runtime to point the SDK at a different Attentive
    /// company: without recording it, a stale sync record from the previous company would
    /// let a subsequent `planUpdateUser` return `.skip` for a call the new company has
    /// never seen.
    func recordSuccessfulSync(email: String?, phone: String?, pushToken: String, domain: String) {
        let normalizedEmail = Self.normalizeContact(email)
        let normalizedPhone = Self.normalizeContact(phone)
        lock.withLock {
            _lastSyncedPushToken = pushToken
            _lastSyncedEmail = normalizedEmail
            _lastSyncedPhone = normalizedPhone
            _lastSyncedDomain = domain
            persistentStorage.save(pushToken as NSString, forKey: Constants.lastSyncedPushTokenKey)
            persistentStorage.save(domain as NSString, forKey: Constants.lastSyncedDomainKey)
            if let email = normalizedEmail {
                persistentStorage.save(email as NSString, forKey: Constants.lastSyncedEmailKey)
            } else {
                persistentStorage.delete(forKey: Constants.lastSyncedEmailKey)
            }
            if let phone = normalizedPhone {
                persistentStorage.save(phone as NSString, forKey: Constants.lastSyncedPhoneKey)
            } else {
                persistentStorage.delete(forKey: Constants.lastSyncedPhoneKey)
            }
        }
    }

    // MARK: - Private helpers

    /// Whitespace-only or empty strings collapse to `nil`, matching how ATTNAPI.updateUser
    /// sends them on the wire (`meta["email"]` is only set when the trimmed value is
    /// non-empty). Keeping normalization in one place means the sync record and the plan
    /// decisions always see the same shape the server saw.
    fileprivate static func normalizeContact(_ value: String?) -> String? {
        guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              !value.isEmpty else { return nil }
        return value
    }

    /// Compares `_identifiers` against the exact `{email, phone}` pair (nils dropped).
    /// Caller MUST already hold `lock`.
    private func identifiersMatchLocked(email: String?, phone: String?) -> Bool {
        let matchesEmail = email == nil
            ? _identifiers[ATTNIdentifierType.email] == nil
            : (_identifiers[ATTNIdentifierType.email] as? String) == email
        let matchesPhone = phone == nil
            ? _identifiers[ATTNIdentifierType.phone] == nil
            : (_identifiers[ATTNIdentifierType.phone] as? String) == phone
        let expectedCount = (email != nil ? 1 : 0) + (phone != nil ? 1 : 0)
        return matchesEmail && matchesPhone && _identifiers.count == expectedCount
    }

    /// True when the sync record was set for this push token AND this domain AND records
    /// the same `{email, phone}` pair. Push-token equality is part of the check because
    /// APNs can rotate the token — the server-side attachment lives per token, so a token
    /// change invalidates any prior confirmation. Domain equality is part of the check
    /// because `ATTNSDK.updateDomain(...)` can retarget the SDK at a different Attentive
    /// company at runtime; a record confirmed against the previous company must not let
    /// the new company's first identity call skip. Caller MUST already hold `lock`.
    private func isSyncRecordMatchingLocked(email: String?, phone: String?, pushToken: String, domain: String) -> Bool {
        guard _lastSyncedPushToken == pushToken, _lastSyncedDomain == domain else { return false }
        return _lastSyncedEmail == email && _lastSyncedPhone == phone
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
