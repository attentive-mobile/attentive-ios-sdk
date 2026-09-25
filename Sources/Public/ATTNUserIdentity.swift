//
//  ATTNUserIdentity.swift
//  attentive-ios-sdk-framework
//
//  Created by Vladimir - Work on 2024-05-29.
//

import CryptoKit
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
        // Sync-record keys. Deliberately NOT the MSDK-469 `lastSynced*` names: an SDK
        // downgraded past MSDK-516 would read a record without `lastSyncedEmail` /
        // `lastSyncedPhone` as "server confirmed detach" and let `clearUser()` skip while the
        // server still links the visitor id to the user. Under new names an older SDK sees no
        // record at all and simply retries.
        static var syncedPushTokenKey: String { "syncRecordV2.pushToken" }
        static var syncedContactDigestKey: String { "syncRecordV2.contactDigest" }
        static var syncedDomainKey: String { "syncRecordV2.domain" }
        static var syncedVisitorIdKey: String { "syncRecordV2.visitorId" }
        static var contactDigestSaltKey: String { "syncRecordV2.contactDigestSalt" }

        // MSDK-469 keys. `lastSyncedEmail` / `lastSyncedPhone` held the raw contact values;
        // they are migrated to a digest and deleted on init (MSDK-516).
        static var legacyPushTokenKey: String { "lastSyncedPushToken" }
        static var legacyEmailKey: String { "lastSyncedEmail" }
        static var legacyPhoneKey: String { "lastSyncedPhone" }
        static var legacyDomainKey: String { "lastSyncedDomain" }
        static var legacyVisitorIdKey: String { "lastSyncedVisitorId" }
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
    // Dropped wholesale whenever the visitor id rotates (MSDK-516) — see `clearSyncRecordLocked`.
    private var lastSyncedPushToken: String?
    // The guards only ever compare the confirmed {email, phone} pair for equality, so the
    // record keeps a salted HMAC of the normalized pair instead of the values themselves —
    // no contact data at rest (MSDK-516). `nil` means the server confirmed an empty pair
    // (a detach).
    private var lastSyncedContactDigest: String?
    // Domain is part of the sync record because `ATTNSDK.updateDomain(...)` can change the
    // Attentive company this device reports to at runtime. Without it, a sync record confirmed
    // against the old company would let `planUpdateUser` / `planClearUser` return `.skip` for
    // a call the new company's backend has never seen — matching what the Android SDK now
    // guards against in the counterpart PR (MSDK-470).
    private var lastSyncedDomain: String?
    // The visitor id the server confirmed the tuple under. Any rotation — from `clearUser()`,
    // from a `.rotatedAndReplaced` outcome, or from a caller invoking the still-public
    // `ATTNUserIdentity.clearUser()` directly — moves `_visitorId` forward while this field
    // stays pinned to the confirmed value. That mismatch is what lets `isSyncRecordMatchingLocked`
    // reject a stale record after an offline logout. Rotation sites also drop the record
    // outright now (MSDK-516), so this is the backstop for a rotation that bypasses them.
    // Without it, a `clearUser()` that rotated locally but whose detach POST failed can be
    // followed by an in-memory-empty relaunch + login-as-A, and the cold-launch adoption
    // branch would `.skip` — leaving the server pinned to the old (V1, A) mapping while the
    // device emits events as V2.
    private var lastSyncedVisitorId: String?
    // Per-install HMAC key for `lastSyncedContactDigest`. Not a secret — it lives in the same
    // store as the digest — but it keeps the digest from being matched against a precomputed
    // table or correlated across devices.
    private let contactDigestSalt: SymmetricKey

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
        self.contactDigestSalt = Self.loadOrCreateContactDigestSalt(persistentStorage)
        Self.migrateLegacySyncRecord(persistentStorage, salt: contactDigestSalt)
        // Load sync state before super.init returns so the very first plan* call after
        // construction sees the persisted record. A failed prior /user-update whose app
        // was killed before the callback fired will show up here as "sync != local" and
        // the next call will retry.
        self.lastSyncedPushToken = persistentStorage.readString(forKey: Constants.syncedPushTokenKey)
        self.lastSyncedContactDigest = persistentStorage.readString(forKey: Constants.syncedContactDigestKey)
        self.lastSyncedDomain = persistentStorage.readString(forKey: Constants.syncedDomainKey)
        self.lastSyncedVisitorId = persistentStorage.readString(forKey: Constants.syncedVisitorIdKey)
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
            clearSyncRecordLocked()
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
        // before sending. If we compared raw inputs against the normalized sync
        // record, "  a@b.com  " and "a@b.com" would look different here even though the
        // server has already recorded them as identical — causing a spurious retry.
        let normalizedEmail = Self.normalizeContact(email)
        let normalizedPhone = Self.normalizeContact(phone)
        let incomingDigest = contactDigest(email: normalizedEmail, phone: normalizedPhone)

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
                contactDigest: incomingDigest,
                pushToken: pushToken,
                domain: domain
            )
            // Cold-launch adoption: local has no user-scoped identifiers (a process
            // restart cleared the in-memory dict) but the persisted sync record already
            // reflects this exact pair for the current push token, domain, AND visitor
            // id. Adopt the pair into `_identifiers` without rotating so the very next
            // call inside this process sees the identifiers as "match" and returns
            // `.skip` cleanly.
            if hasNoUserScopedIdentifiers && syncMatches {
                if let email = normalizedEmail { _identifiers[ATTNIdentifierType.email] = email }
                if let phone = normalizedPhone { _identifiers[ATTNIdentifierType.phone] = phone }
                return .adoptedFromSyncRecord
            }
            let localMatchesIncoming = identifiersMatchLocked(email: normalizedEmail, phone: normalizedPhone)
            // Rotate when local doesn't match the request, OR when local matches only
            // because `identify()`/`mergeIdentifiers` pre-seeded the same keys under a
            // visitor id the server has confirmed as a DIFFERENT identity. Without the
            // second condition, `identify([email: B])` after a synced `updateUser(A)`
            // would let `updateUser(B)` fall into `.retryWithoutRotation` and POST B
            // under V1 — attaching B's email and push token to A's visitor id server-
            // side. The record having non-nil email/phone that disagree with the
            // incoming pair is the signal that this is a new identity, not a retry.
            let syncRecordHasDifferentIdentity = lastSyncedContactDigest != nil
                && lastSyncedContactDigest != incomingDigest
            if !localMatchesIncoming || syncRecordHasDifferentIdentity {
                var replacement: [String: Any] = [:]
                if let email = normalizedEmail { replacement[ATTNIdentifierType.email] = email }
                if let phone = normalizedPhone { replacement[ATTNIdentifierType.phone] = phone }
                _identifiers = replacement
                let id = visitorService.createNewVisitorId()
                _visitorId = id
                clearSyncRecordLocked()
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
    /// - Returns: `.skip` when local is already empty AND the last confirmed sync (for
    ///   the same push token, domain, and visitor id) recorded an empty state; caller
    ///   can skip everything. `.rotatedAndReplaced` in every other case; the visitor id
    ///   has been rotated and `_identifiers` cleared, and the caller must fire
    ///   `/user-update` (when a push token is present) with the new visitor id.
    ///
    /// Why always rotate on non-`.skip`: pre-guard `clearUser()` rotated unconditionally,
    /// and the public doc still promises "generate a new anonymous visitor ID." A cold
    /// launch after a synced `updateUser(A)` starts with empty local + a sync record
    /// pinning V1↔A. A logout from that state must rotate — otherwise the persisted
    /// visitor id keeps flowing on subsequent events, and the server keeps associating
    /// them with A. Only the true no-op case (server already confirmed detach for the
    /// current tuple) preserves the visitor id.
    func planClearUser(pushToken: String, domain: String) -> ATTNIdentitySyncDecision {
        enum Outcome {
            case mutated(newVisitorId: String)
            case alreadyEmptyAndSynced
        }
        let outcome: Outcome = lock.withLock { () -> Outcome in
            let syncMatchesDetached = _identifiers.isEmpty
                && isSyncRecordMatchingLocked(contactDigest: nil, pushToken: pushToken, domain: domain)
            if syncMatchesDetached {
                return .alreadyEmptyAndSynced
            }
            // Either local is non-empty (needs clearing), or local is empty but the
            // server has not confirmed detach for the current push token, domain, and
            // visitor id — meaning the persisted visitor id may still be linked to the
            // previous user server-side. Rotate and, at the caller, fire detach.
            _identifiers = [:]
            let id = visitorService.createNewVisitorId()
            _visitorId = id
            // Drop the record here rather than waiting for the detach to succeed: with no
            // push token no detach fires, and a failed one never records, so waiting would
            // leave the previous user's record on disk indefinitely (MSDK-516).
            clearSyncRecordLocked()
            return .mutated(newVisitorId: id)
        }
        switch outcome {
        case .mutated(let newVisitorId):
            visitorService.logNewVisitorId(newVisitorId)
            return .rotatedAndReplaced
        case .alreadyEmptyAndSynced:
            return .skip
        }
    }

    /// Called from the `/user-update` completion when the request succeeded (HTTP 2xx,
    /// no transport error). Records the tuple the server confirmed — a digest of the
    /// email/phone pair, push token, domain, and the visitor id the request was sent under —
    /// so the next `planUpdateUser` / `planClearUser` can distinguish "already synced" from
    /// "needs retry". Persisted so a relaunch preserves the confirmation.
    ///
    /// `visitorId` is the id captured at request-time (not read from `self` here) because
    /// a mid-flight rotation would otherwise let the record pin itself to a value the
    /// server never saw. If the visitor id has rotated since the request, the response is
    /// dropped: the rotation already cleared the record, and writing it back would restore
    /// the previous user's state after a logout. Nil email/phone are stored as absence —
    /// matching what the server actually sees when clearUser posts an empty `m: {}` — so a
    /// subsequent clearUser with an empty local state correctly resolves to `.skip`.
    func recordSuccessfulSync(email: String?, phone: String?, pushToken: String, domain: String, visitorId: String) {
        let digest = contactDigest(email: Self.normalizeContact(email), phone: Self.normalizeContact(phone))
        lock.withLock {
            guard visitorId == _visitorId else { return }
            lastSyncedPushToken = pushToken
            lastSyncedContactDigest = digest
            lastSyncedDomain = domain
            lastSyncedVisitorId = visitorId
            persistentStorage.save(pushToken as NSString, forKey: Constants.syncedPushTokenKey)
            persistentStorage.save(domain as NSString, forKey: Constants.syncedDomainKey)
            persistentStorage.save(visitorId as NSString, forKey: Constants.syncedVisitorIdKey)
            if let digest {
                persistentStorage.save(digest as NSString, forKey: Constants.syncedContactDigestKey)
            } else {
                persistentStorage.delete(forKey: Constants.syncedContactDigestKey)
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
    /// the same `{email, phone}` pair (by digest) AND was confirmed under the current
    /// `_visitorId`. Push-token equality is part of the check because APNs can rotate the
    /// token — the server-side attachment lives per token, so a token change invalidates any
    /// prior confirmation. Domain equality handles `ATTNSDK.updateDomain(...)`; a record
    /// confirmed against the previous Attentive company must not let the new company's
    /// first identity call skip. Visitor-id equality handles any rotation site that does not
    /// clear the record itself — after rotation the sync record is confirmed under an id the
    /// device no longer sends, so we must not skip or adopt. Caller MUST already hold `lock`.
    private func isSyncRecordMatchingLocked(contactDigest: String?, pushToken: String, domain: String) -> Bool {
        guard lastSyncedPushToken == pushToken,
              lastSyncedDomain == domain,
              lastSyncedVisitorId == _visitorId else { return false }
        return lastSyncedContactDigest == contactDigest
    }

    /// Forgets the sync record in memory and on disk. Called at every visitor-id rotation:
    /// the record describes what the server confirmed for the previous visitor id, so after
    /// a rotation it can no longer produce a `.skip` — keeping it would only keep a trace of
    /// the previous user on the device. A missing record makes the next call re-send
    /// `/user-update`, which is the safe direction. Caller MUST already hold `lock`.
    private func clearSyncRecordLocked() {
        lastSyncedPushToken = nil
        lastSyncedContactDigest = nil
        lastSyncedDomain = nil
        lastSyncedVisitorId = nil
        persistentStorage.delete(forKey: Constants.syncedPushTokenKey)
        persistentStorage.delete(forKey: Constants.syncedContactDigestKey)
        persistentStorage.delete(forKey: Constants.syncedDomainKey)
        persistentStorage.delete(forKey: Constants.syncedVisitorIdKey)
    }

    /// Non-reversible stand-in for an already-normalized `{email, phone}` pair. Returns `nil`
    /// for the empty pair so "confirmed detach" stays representable as absence.
    private func contactDigest(email: String?, phone: String?) -> String? {
        Self.contactDigest(email: email, phone: phone, salt: contactDigestSalt)
    }

    private static func contactDigest(email: String?, phone: String?, salt: SymmetricKey) -> String? {
        guard email != nil || phone != nil else { return nil }
        // Length-prefix each field so ("ab", "c") and ("a", "bc") can't produce the same input.
        let email = email ?? ""
        let phone = phone ?? ""
        let message = "\(email.utf8.count):\(email)|\(phone.utf8.count):\(phone)"
        let code = HMAC<SHA256>.authenticationCode(for: Data(message.utf8), using: salt)
        return Data(code).base64EncodedString()
    }

    private static func loadOrCreateContactDigestSalt(_ storage: ATTNPersistentStorageProtocol) -> SymmetricKey {
        if let encoded = storage.readString(forKey: Constants.contactDigestSaltKey),
           let data = Data(base64Encoded: encoded) {
            return SymmetricKey(data: data)
        }
        // A new salt invalidates any digest written under a lost one; the next call retries.
        let salt = SymmetricKey(size: .bits256)
        let encoded = salt.withUnsafeBytes { Data($0).base64EncodedString() }
        storage.save(encoded as NSString, forKey: Constants.contactDigestSaltKey)
        return salt
    }

    /// Converts an MSDK-469 record (raw email/phone on disk) into the digest format and
    /// deletes the legacy keys. Migrating rather than just deleting keeps upgraded devices
    /// from treating their confirmed identity as unsynced, which would rotate the visitor id
    /// and re-POST on the first `updateUser` after the upgrade. A record missing any of
    /// push token, domain, or visitor id could never match anyway, so it is only deleted.
    private static func migrateLegacySyncRecord(_ storage: ATTNPersistentStorageProtocol, salt: SymmetricKey) {
        defer {
            storage.delete(forKey: Constants.legacyPushTokenKey)
            storage.delete(forKey: Constants.legacyEmailKey)
            storage.delete(forKey: Constants.legacyPhoneKey)
            storage.delete(forKey: Constants.legacyDomainKey)
            storage.delete(forKey: Constants.legacyVisitorIdKey)
        }
        guard let pushToken = storage.readString(forKey: Constants.legacyPushTokenKey),
              let domain = storage.readString(forKey: Constants.legacyDomainKey),
              let visitorId = storage.readString(forKey: Constants.legacyVisitorIdKey) else { return }
        let digest = contactDigest(
            email: normalizeContact(storage.readString(forKey: Constants.legacyEmailKey)),
            phone: normalizeContact(storage.readString(forKey: Constants.legacyPhoneKey)),
            salt: salt
        )
        storage.save(pushToken as NSString, forKey: Constants.syncedPushTokenKey)
        storage.save(domain as NSString, forKey: Constants.syncedDomainKey)
        storage.save(visitorId as NSString, forKey: Constants.syncedVisitorIdKey)
        if let digest {
            storage.save(digest as NSString, forKey: Constants.syncedContactDigestKey)
        } else {
            storage.delete(forKey: Constants.syncedContactDigestKey)
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
