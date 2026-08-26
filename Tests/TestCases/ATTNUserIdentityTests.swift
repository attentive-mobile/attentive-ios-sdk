//
//  ATTNUserIdentityTests.swift
//  attentive-ios-sdk Tests
//
//  Created by Vladimir - Work on 2024-06-04.
//

import XCTest
import os
@testable import ATTNSDKFramework

final class ATTNUserIdentityTests: XCTestCase {
    func testInit_doesNotThrow() {
        XCTAssertNoThrow(ATTNUserIdentity(identifiers: [:]))
    }

    func testInitWithIdentifiers_emptyIdentifiers_succeeds() {
        let identity = ATTNUserIdentity(identifiers: [:])
        XCTAssertEqual(identity.identifiers.count, .zero)
    }

    func testInitWithIdentifiers_validIdentifiers_succeeds() {
        let identity = ATTNUserIdentity(identifiers: [ATTNIdentifierType.clientUserId: "someValue"])
        XCTAssertEqual("someValue", identity.identifiers[ATTNIdentifierType.clientUserId] as! String)
    }

    func testInitWithIdentifiers_invalidIdentifiers_doesNotThrow() {
        XCTAssertNoThrow(ATTNUserIdentity(identifiers: [ATTNIdentifierType.clientUserId: [:]]))
    }

    func testMergeIdentifiers_noExistingIdentifiersAndMergeEmptyIdentifiers_identifiersAreEmpty() {
        let identity = ATTNUserIdentity()
        identity.mergeIdentifiers([:])

        XCTAssertEqual(0, identity.identifiers.count)
    }

    func testMergeIdentifiers_noExistingIdentifiersAndMergeNonEmptyIdentifiers_identifiersAreMerged() {
        let identity = ATTNUserIdentity()
        identity.mergeIdentifiers([ATTNIdentifierType.clientUserId: "someValue"])

        XCTAssertEqual(1, identity.identifiers.count)
    }

    func testMergeIdentifiers_existingIdentifiersAndMergeEmptyIdentifiers_identifiersDidNotChange() {
        let identity = ATTNUserIdentity(identifiers: [ATTNIdentifierType.clientUserId: "someValue"])
        identity.mergeIdentifiers([:])

        XCTAssertEqual(1, identity.identifiers.count)
        XCTAssertEqual("someValue", identity.identifiers[ATTNIdentifierType.clientUserId] as! String)
    }

    func testMergeIdentifiers_existingIdentifiersAndMergeNewIdentifiers_identifiersUpdated() {
        let identity = ATTNUserIdentity(identifiers: [
            ATTNIdentifierType.clientUserId: "someValue",
            ATTNIdentifierType.email: "someEmail"
        ])
        identity.mergeIdentifiers([
            ATTNIdentifierType.clientUserId: "newValue",
            ATTNIdentifierType.phone: "somePhone"
        ])

        XCTAssertEqual(3, identity.identifiers.count)
        XCTAssertEqual("newValue", identity.identifiers[ATTNIdentifierType.clientUserId] as! String)
        XCTAssertEqual("somePhone", identity.identifiers[ATTNIdentifierType.phone] as! String)
        XCTAssertEqual("someEmail", identity.identifiers[ATTNIdentifierType.email] as! String)
    }

    func testClearUser_noExistingIdentifiers_noop() {
        XCTAssertNoThrow(ATTNUserIdentity().clearUser())
    }

    func testClearUser_existingIdentifiers_clearsIdentifiers() {
        let identity = ATTNUserIdentity(identifiers: [ATTNIdentifierType.clientUserId: "someValue"])
        identity.clearUser()

        XCTAssertEqual(0, identity.identifiers.count)
    }

    func testClearUser_existingIdentifiersAndMergeAfterClearing_clearsIdentifiers() {
        let identity = ATTNUserIdentity(identifiers: [ATTNIdentifierType.clientUserId: "someValue"])
        identity.clearUser()

        identity.mergeIdentifiers([ATTNIdentifierType.clientUserId: "someValue"])
        XCTAssertEqual(1, identity.identifiers.count)
        XCTAssertEqual("someValue", identity.identifiers[ATTNIdentifierType.clientUserId] as! String)
    }

    // MARK: MSDK-469 sync-aware primitives — planClearUser, planUpdateUser, recordSuccessfulSync

    /// Builds an identity with mock persistent storage so each test controls its sync
    /// record independently of the shared real UserDefaults. All the plan* tests below use
    /// this factory rather than the public init.
    private func makeIsolatedIdentity(identifiers: [String: Any] = [:]) -> (ATTNUserIdentity, ATTNPersistentStorageMock) {
        let storage = ATTNPersistentStorageMock()
        let identity = ATTNUserIdentity(
            identifiers: identifiers,
            visitorService: ATTNVisitorService(
                persistentStorage: storage,
                logger: Logger(OSLog.disabled)
            ),
            persistentStorage: storage
        )
        return (identity, storage)
    }

    private let testToken = "010203"
    private let testDomain = "test-domain"

    // -- planClearUser ---------------------------------------------------------------

    func testPlanClearUser_emptyLocalAndNoSyncRecord_rotates() {
        // Fresh device with a push token but no confirmed sync yet: the server MIGHT have
        // the token attached to a previous user from before the SDK was upgraded, or from a
        // prior process where /user-update never completed. Rotate visitor id + fire detach
        // — the persisted visitor id from that prior process may still be linked to the
        // previous user server-side (MSDK-469 Comment 3).
        let (identity, _) = makeIsolatedIdentity()
        let visitorIdBefore = identity.visitorId

        XCTAssertEqual(identity.planClearUser(pushToken: testToken, domain: testDomain), .rotatedAndReplaced)
        XCTAssertNotEqual(identity.visitorId, visitorIdBefore,
                          "clearUser must rotate whenever a detach fires; skipping rotation leaves the persisted visitor id linked to the previous user")
    }

    func testPlanClearUser_emptyLocalAndMatchingSyncRecord_returnsSkip() {
        // After a successful clearUser, planClearUser sees local empty and sync = empty for
        // the same push token. This is the "true no-op" case the Aero fanout depends on.
        let (identity, _) = makeIsolatedIdentity()
        identity.recordSuccessfulSync(email: nil, phone: nil, pushToken: testToken, domain: testDomain, visitorId: identity.visitorId)
        let visitorIdBefore = identity.visitorId

        XCTAssertEqual(identity.planClearUser(pushToken: testToken, domain: testDomain), .skip)
        XCTAssertEqual(identity.visitorId, visitorIdBefore)
    }

    func testPlanClearUser_emptyLocalButSyncRecordForDifferentToken_rotates() {
        // APNs rotated the device token. The prior sync applies to a different token; the
        // new one has not been detached server-side yet. Rotate + detach — the persisted
        // visitor id is still linked to the previous user on the server for the OLD token.
        let (identity, _) = makeIsolatedIdentity()
        identity.recordSuccessfulSync(email: nil, phone: nil, pushToken: "old-token", domain: testDomain, visitorId: identity.visitorId)
        let visitorIdBefore = identity.visitorId

        XCTAssertEqual(identity.planClearUser(pushToken: "new-token", domain: testDomain), .rotatedAndReplaced)
        XCTAssertNotEqual(identity.visitorId, visitorIdBefore)
    }

    func testPlanClearUser_emptyLocalButSyncRecordNonEmpty_rotates() {
        // MSDK-469 Comment 3: server last confirmed the token attached to email X. Local
        // is empty (fresh process init after a prior updateUser under this visitor id),
        // but the server still thinks the visitor id is attached to X. Must rotate the
        // visitor id — otherwise every subsequent event flows under an id the server
        // still associates with X, defeating logout.
        let (identity, _) = makeIsolatedIdentity()
        identity.recordSuccessfulSync(email: "user@example.com", phone: nil, pushToken: testToken, domain: testDomain, visitorId: identity.visitorId)
        let visitorIdBefore = identity.visitorId

        XCTAssertEqual(identity.planClearUser(pushToken: testToken, domain: testDomain), .rotatedAndReplaced)
        XCTAssertNotEqual(identity.visitorId, visitorIdBefore,
                          "logout after relaunch (empty local + sync record shows attached) must rotate — otherwise persisted visitor id keeps flowing to the prior user")
    }

    func testPlanClearUser_nonEmptyLocal_returnsRotatedAndReplaced() {
        let (identity, _) = makeIsolatedIdentity(identifiers: [ATTNIdentifierType.email: "user@example.com"])
        let visitorIdBefore = identity.visitorId

        XCTAssertEqual(identity.planClearUser(pushToken: testToken, domain: testDomain), .rotatedAndReplaced)
        XCTAssertEqual(identity.identifiers.count, 0)
        XCTAssertNotEqual(identity.visitorId, visitorIdBefore)
    }

    // -- planUpdateUser --------------------------------------------------------------

    func testPlanUpdateUser_localDiffers_returnsRotatedAndReplaced() {
        let (identity, _) = makeIsolatedIdentity()
        let visitorIdBefore = identity.visitorId

        XCTAssertEqual(
            identity.planUpdateUser(email: "user@example.com", phone: "+15551234567", pushToken: testToken, domain: testDomain),
            .rotatedAndReplaced
        )
        XCTAssertEqual(identity.identifiers[ATTNIdentifierType.email] as? String, "user@example.com")
        XCTAssertEqual(identity.identifiers[ATTNIdentifierType.phone] as? String, "+15551234567")
        XCTAssertNotEqual(identity.visitorId, visitorIdBefore)
    }

    func testPlanUpdateUser_localMatchesAndSyncMatches_returnsSkip() {
        let (identity, _) = makeIsolatedIdentity(identifiers: [
            ATTNIdentifierType.email: "user@example.com",
            ATTNIdentifierType.phone: "+15551234567"
        ])
        identity.recordSuccessfulSync(email: "user@example.com", phone: "+15551234567", pushToken: testToken, domain: testDomain, visitorId: identity.visitorId)
        let visitorIdBefore = identity.visitorId

        XCTAssertEqual(
            identity.planUpdateUser(email: "user@example.com", phone: "+15551234567", pushToken: testToken, domain: testDomain),
            .skip
        )
        XCTAssertEqual(identity.visitorId, visitorIdBefore)
    }

    func testPlanUpdateUser_localMatchesButSyncDoesNot_returnsRetry() {
        // The core Codex P1 #2 case at the primitive level: previous updateUser mutated
        // local but its /user-update never succeeded, so sync record is empty. Retry.
        let (identity, _) = makeIsolatedIdentity(identifiers: [
            ATTNIdentifierType.email: "user@example.com",
            ATTNIdentifierType.phone: "+15551234567"
        ])
        // No recordSuccessfulSync call — mimics a failed prior /user-update.
        let visitorIdBefore = identity.visitorId

        XCTAssertEqual(
            identity.planUpdateUser(email: "user@example.com", phone: "+15551234567", pushToken: testToken, domain: testDomain),
            .retryWithoutRotation
        )
        XCTAssertEqual(identity.visitorId, visitorIdBefore,
                       "retry must not rotate — same identity, no reason to churn the visitor id")
    }

    func testPlanUpdateUser_localMatchesButSyncForDifferentToken_returnsRetry() {
        // APNs rotated the token; the old token's attachment is stale for the new one.
        let (identity, _) = makeIsolatedIdentity(identifiers: [
            ATTNIdentifierType.email: "user@example.com",
            ATTNIdentifierType.phone: "+15551234567"
        ])
        identity.recordSuccessfulSync(email: "user@example.com", phone: "+15551234567", pushToken: "old-token", domain: testDomain, visitorId: identity.visitorId)

        XCTAssertEqual(
            identity.planUpdateUser(email: "user@example.com", phone: "+15551234567", pushToken: "new-token", domain: testDomain),
            .retryWithoutRotation
        )
    }

    func testPlanUpdateUser_extraIdentifierStored_returnsRotatedAndReplaced() {
        // A clientUserId in the stored set means local ≠ incoming {email, phone} — the
        // count mismatch forces the switch to run and drops the extra.
        let (identity, _) = makeIsolatedIdentity(identifiers: [
            ATTNIdentifierType.email: "user@example.com",
            ATTNIdentifierType.phone: "+15551234567",
            ATTNIdentifierType.clientUserId: "customer-123"
        ])

        XCTAssertEqual(
            identity.planUpdateUser(email: "user@example.com", phone: "+15551234567", pushToken: testToken, domain: testDomain),
            .rotatedAndReplaced
        )
        XCTAssertNil(identity.identifiers[ATTNIdentifierType.clientUserId])
    }

    func testPlanUpdateUser_normalizesWhitespaceForCompareAndStorage() {
        // Whitespace on inputs must collapse — both for the local-equality check and for
        // what gets stored, so subsequent same-value calls hit .skip.
        let (identity, _) = makeIsolatedIdentity()
        _ = identity.planUpdateUser(email: "  user@example.com  ", phone: " +15551234567 ", pushToken: testToken, domain: testDomain)
        identity.recordSuccessfulSync(email: "user@example.com", phone: "+15551234567", pushToken: testToken, domain: testDomain, visitorId: identity.visitorId)

        XCTAssertEqual(identity.identifiers[ATTNIdentifierType.email] as? String, "user@example.com",
                       "planUpdateUser must store the normalized value, not the raw whitespaced input")
        XCTAssertEqual(
            identity.planUpdateUser(email: "user@example.com", phone: "+15551234567", pushToken: testToken, domain: testDomain),
            .skip
        )
    }

    // -- recordSuccessfulSync + persistence ------------------------------------------

    func testRecordSuccessfulSync_persistsAcrossNewIdentityInstance() {
        // A relaunch spins up a fresh ATTNUserIdentity from disk. The sync record must
        // survive so the first plan* call after relaunch respects the prior confirmation.
        let sharedStorage = ATTNPersistentStorageMock()
        let visitorService = ATTNVisitorService(
            persistentStorage: sharedStorage,
            logger: Logger(OSLog.disabled)
        )

        let firstLaunch = ATTNUserIdentity(
            identifiers: [
                ATTNIdentifierType.email: "user@example.com",
                ATTNIdentifierType.phone: "+15551234567"
            ],
            visitorService: visitorService,
            persistentStorage: sharedStorage
        )
        firstLaunch.recordSuccessfulSync(email: "user@example.com", phone: "+15551234567", pushToken: testToken, domain: testDomain, visitorId: firstLaunch.visitorId)

        // Rebuild — mimics fresh process init reading from the same storage.
        let secondLaunch = ATTNUserIdentity(
            identifiers: [
                ATTNIdentifierType.email: "user@example.com",
                ATTNIdentifierType.phone: "+15551234567"
            ],
            visitorService: visitorService,
            persistentStorage: sharedStorage
        )
        XCTAssertEqual(
            secondLaunch.planUpdateUser(email: "user@example.com", phone: "+15551234567", pushToken: testToken, domain: testDomain),
            .skip,
            "Persisted sync record must survive across ATTNUserIdentity instances (i.e. app relaunches)"
        )
    }

    func testRecordSuccessfulSync_emptyValuesPersistAsDetach() {
        // A successful clearUser records nil email/phone. On relaunch that must read back as
        // "server confirmed detach for this token," not as "no sync record at all."
        let sharedStorage = ATTNPersistentStorageMock()
        let visitorService = ATTNVisitorService(
            persistentStorage: sharedStorage,
            logger: Logger(OSLog.disabled)
        )

        let firstLaunch = ATTNUserIdentity(
            identifiers: [:],
            visitorService: visitorService,
            persistentStorage: sharedStorage
        )
        firstLaunch.recordSuccessfulSync(email: nil, phone: nil, pushToken: testToken, domain: testDomain, visitorId: firstLaunch.visitorId)

        let secondLaunch = ATTNUserIdentity(
            identifiers: [:],
            visitorService: visitorService,
            persistentStorage: sharedStorage
        )
        XCTAssertEqual(
            secondLaunch.planClearUser(pushToken: testToken, domain: testDomain),
            .skip,
            "Persisted detach confirmation must survive so a subsequent clearUser is a no-op"
        )
    }

    func testRecordSuccessfulSync_overwritesPreviousEmailWithNil() {
        // updateUser(email=A) succeeds, then clearUser() succeeds. The sync record must now
        // reflect the empty state — not still hold email=A.
        let (identity, _) = makeIsolatedIdentity()
        identity.recordSuccessfulSync(email: "user@example.com", phone: nil, pushToken: testToken, domain: testDomain, visitorId: identity.visitorId)
        identity.recordSuccessfulSync(email: nil, phone: nil, pushToken: testToken, domain: testDomain, visitorId: identity.visitorId)

        XCTAssertEqual(
            identity.planClearUser(pushToken: testToken, domain: testDomain),
            .skip,
            "recordSuccessfulSync(nil, nil, …) must clear the previously-recorded email"
        )
    }

    // -- Cold-launch adoption --------------------------------------------------------

    func testPlanUpdateUser_coldLaunch_localEmptyButSyncMatches_returnsSkipAndAdoptsIdentifiers() {
        // Simulates the exact Aero-style regression this branch is chasing. Host apps that
        // call `updateUser(email, phone)` from launch code start each process with
        // `_identifiers == {}` because email/phone aren't persisted anywhere. Without the
        // adoption branch, `identifiersMatchLocked` would see `{}` vs `{email, phone}`,
        // return false, rotate the visitor id, and POST /user-update on every cold launch.
        // With the adoption branch, the persisted sync record confirms the pair already
        // matches on the server and the call resolves to `.skip` — visitor id kept, no POST.
        let sharedStorage = ATTNPersistentStorageMock()
        let visitorService = ATTNVisitorService(
            persistentStorage: sharedStorage,
            logger: Logger(OSLog.disabled)
        )

        let firstLaunch = ATTNUserIdentity(
            identifiers: [
                ATTNIdentifierType.email: "user@example.com",
                ATTNIdentifierType.phone: "+15551234567"
            ],
            visitorService: visitorService,
            persistentStorage: sharedStorage
        )
        firstLaunch.recordSuccessfulSync(email: "user@example.com", phone: "+15551234567", pushToken: testToken, domain: testDomain, visitorId: firstLaunch.visitorId)

        // Second launch: identifiers dict starts empty (in-memory only, so the process
        // restart drops them). Sync record survives on disk.
        let secondLaunch = ATTNUserIdentity(
            identifiers: [:],
            visitorService: visitorService,
            persistentStorage: sharedStorage
        )
        let visitorIdBefore = secondLaunch.visitorId
        XCTAssertTrue(secondLaunch.identifiers.isEmpty,
                      "precondition: identifiers must be empty at cold launch — email/phone are in-memory only")

        XCTAssertEqual(
            secondLaunch.planUpdateUser(email: "user@example.com", phone: "+15551234567", pushToken: testToken, domain: testDomain),
            .skip,
            "Cold-launch updateUser with matching persisted sync record must SKIP — this is the Aero fanout stop"
        )
        XCTAssertEqual(secondLaunch.visitorId, visitorIdBefore,
                       "adoption branch must not rotate the visitor id")
        // Adoption must also populate `_identifiers` so the very next in-process call sees
        // local as matching (avoids relying on the sync record twice).
        XCTAssertEqual(secondLaunch.identifiers[ATTNIdentifierType.email] as? String, "user@example.com")
        XCTAssertEqual(secondLaunch.identifiers[ATTNIdentifierType.phone] as? String, "+15551234567")
    }

    func testPlanUpdateUser_coldLaunch_localEmptyAndNoSyncRecord_rotatesAsBefore() {
        // First real updateUser call on a brand-new install must still rotate — no sync
        // record on disk means the adoption branch has nothing to adopt. Guards against
        // the adoption branch accidentally suppressing genuine first-time identifications.
        let (identity, _) = makeIsolatedIdentity()
        let visitorIdBefore = identity.visitorId

        XCTAssertEqual(
            identity.planUpdateUser(email: "user@example.com", phone: "+15551234567", pushToken: testToken, domain: testDomain),
            .rotatedAndReplaced
        )
        XCTAssertNotEqual(identity.visitorId, visitorIdBefore)
    }

    func testPlanUpdateUser_coldLaunch_localEmptyButSyncRecordMismatchesEmail_rotates() {
        // Adoption is exact-match. A stored sync of (A, phone) must not adopt an incoming
        // (B, phone) — that's a real identity switch. Rotates + replaces.
        let sharedStorage = ATTNPersistentStorageMock()
        let visitorService = ATTNVisitorService(
            persistentStorage: sharedStorage,
            logger: Logger(OSLog.disabled)
        )
        let firstLaunch = ATTNUserIdentity(identifiers: [:], visitorService: visitorService, persistentStorage: sharedStorage)
        firstLaunch.recordSuccessfulSync(email: "old@example.com", phone: "+15551234567", pushToken: testToken, domain: testDomain, visitorId: firstLaunch.visitorId)

        let secondLaunch = ATTNUserIdentity(identifiers: [:], visitorService: visitorService, persistentStorage: sharedStorage)
        let visitorIdBefore = secondLaunch.visitorId

        XCTAssertEqual(
            secondLaunch.planUpdateUser(email: "new@example.com", phone: "+15551234567", pushToken: testToken, domain: testDomain),
            .rotatedAndReplaced
        )
        XCTAssertNotEqual(secondLaunch.visitorId, visitorIdBefore)
        XCTAssertEqual(secondLaunch.identifiers[ATTNIdentifierType.email] as? String, "new@example.com")
    }

    // -- Domain-scoped sync record ---------------------------------------------------

    func testPlanUpdateUser_domainChanged_returnsRotatedAndReplaced() {
        // Host calls `ATTNSDK.updateDomain(...)` between calls. The sync record was
        // confirmed against the old company; the new company has never seen this identity.
        // Must NOT skip — the new company's backend needs the /user-update.
        let (identity, _) = makeIsolatedIdentity(identifiers: [
            ATTNIdentifierType.email: "user@example.com",
            ATTNIdentifierType.phone: "+15551234567"
        ])
        identity.recordSuccessfulSync(email: "user@example.com", phone: "+15551234567", pushToken: testToken, domain: "old-domain", visitorId: identity.visitorId)

        XCTAssertEqual(
            identity.planUpdateUser(email: "user@example.com", phone: "+15551234567", pushToken: testToken, domain: "new-domain"),
            .retryWithoutRotation,
            "Domain change must invalidate the sync record — the new company hasn't confirmed this identity"
        )
    }

    func testPlanClearUser_domainChanged_rotates() {
        // Same shape as the updateUser variant. A detach confirmed against old-domain must
        // not silence a subsequent clearUser after a domain switch: the new company has
        // never been told to detach, and (per Comment 3) rotating is the safe default
        // whenever we fire a detach against a fresh company/token.
        let (identity, _) = makeIsolatedIdentity()
        identity.recordSuccessfulSync(email: nil, phone: nil, pushToken: testToken, domain: "old-domain", visitorId: identity.visitorId)
        let visitorIdBefore = identity.visitorId

        XCTAssertEqual(
            identity.planClearUser(pushToken: testToken, domain: "new-domain"),
            .rotatedAndReplaced
        )
        XCTAssertNotEqual(identity.visitorId, visitorIdBefore)
    }

    func testRecordSuccessfulSync_persistsDomainAcrossNewIdentityInstance() {
        // Persistence check for the new field: relaunch, look up the same tuple, expect
        // `.skip`. Without persisted `lastSyncedDomain`, `isSyncRecordMatchingLocked` would
        // see nil vs `testDomain` and return retry after every relaunch.
        let sharedStorage = ATTNPersistentStorageMock()
        let visitorService = ATTNVisitorService(
            persistentStorage: sharedStorage,
            logger: Logger(OSLog.disabled)
        )
        let firstLaunch = ATTNUserIdentity(
            identifiers: [ATTNIdentifierType.email: "user@example.com"],
            visitorService: visitorService,
            persistentStorage: sharedStorage
        )
        firstLaunch.recordSuccessfulSync(email: "user@example.com", phone: nil, pushToken: testToken, domain: testDomain, visitorId: firstLaunch.visitorId)

        let secondLaunch = ATTNUserIdentity(
            identifiers: [ATTNIdentifierType.email: "user@example.com"],
            visitorService: visitorService,
            persistentStorage: sharedStorage
        )
        XCTAssertEqual(
            secondLaunch.planUpdateUser(email: "user@example.com", phone: nil, pushToken: testToken, domain: testDomain),
            .skip,
            "Domain must persist across relaunches or every cold launch retries the /user-update"
        )
    }

    // MARK: Concurrency

    func testMergeIdentifiers_concurrentMerges_preservesAllKeys() {
        let identity = ATTNUserIdentity()
        // Each iteration writes a *different* top-level key. With non-atomic merge the
        // read-modify-write would drop keys under contention; with proper locking every
        // merge composes, so all 200 keys must survive.
        DispatchQueue.concurrentPerform(iterations: 200) { i in
            identity.mergeIdentifiers(["dynamic_key_\(i)": "value\(i)"])
        }
        XCTAssertEqual(identity.identifiers.count, 200)
    }

    func testMergeAndRead_concurrentReadersAndWriters_doesNotCrash() {
        let identity = ATTNUserIdentity(identifiers: [ATTNIdentifierType.email: "seed@test.com"])
        runConcurrently(iterations: 200, queueLabels: ["writer", "reader"]) { i, queueIndex in
            if queueIndex == 0 {
                identity.mergeIdentifiers([ATTNIdentifierType.email: "user\(i)@test.com"])
            } else {
                _ = identity.identifiers
                _ = identity.visitorId
            }
        }
    }

    func testClearUser_concurrentClearAndMerge_doesNotCrash() {
        // Inject in-memory storage and a disabled logger: the test asserts the
        // lock, not disk or log I/O. The disabled logger matters on CI — even
        // with clearUser() logging outside its critical section, each os_log
        // call is still on the timed path (the dispatch block doesn't finish
        // until the log returns), and CircleCI's log capture serializes os_log
        // at ~75ms/call, which at 200 iterations adds ~15s of pure log latency.
        let identity = ATTNUserIdentity(
            identifiers: [:],
            visitorService: ATTNVisitorService(
                persistentStorage: ATTNPersistentStorageMock(),
                logger: Logger(OSLog.disabled)
            )
        )
        runConcurrently(iterations: 200, queueLabels: ["merge", "clear"]) { i, queueIndex in
            if queueIndex == 0 {
                identity.mergeIdentifiers([ATTNIdentifierType.email: "user\(i)@test.com"])
            } else {
                identity.clearUser()
            }
        }
    }

    // MARK: MSDK-469 review — three P1s from usharif-attentive (2026-08-25)

    /// Comment 1: sync record stuck after an offline rotation invalidates the visitor id.
    /// Repro: updateUser(A) syncs under V1 → record=(A, token, domain, V1). clearUser()
    /// rotates locally to V2 but the detach POST fails so the record still says V1.
    /// Re-login as A on a fresh process: local is empty + record's identifiers match A →
    /// pre-fix adoption returned `.skip` and never sent V2 to the server. After including
    /// the visitor id in the sync record, V2 != V1 so adoption declines and the flow
    /// rotates + fires the /user-update.
    func testPlanUpdateUser_syncRecordFromRotatedVisitorId_doesNotAdopt() {
        let sharedStorage = ATTNPersistentStorageMock()
        let visitorService = ATTNVisitorService(
            persistentStorage: sharedStorage,
            logger: Logger(OSLog.disabled)
        )
        // Simulate the prior process: sync (A, token, domain, V1), then a local rotation
        // (clearUser) that never got its detach confirmed — record still pins V1.
        let firstProcess = ATTNUserIdentity(
            identifiers: [ATTNIdentifierType.email: "user@example.com"],
            visitorService: visitorService,
            persistentStorage: sharedStorage
        )
        firstProcess.recordSuccessfulSync(email: "user@example.com", phone: nil, pushToken: testToken, domain: testDomain, visitorId: firstProcess.visitorId)
        firstProcess.clearUser() // rotates in-memory + on disk (visitorService persists), sync record unchanged

        // Second process: fresh identity, reads new visitor id (V2) from storage. Sync
        // record still says V1. Cold-launch adoption must NOT fire.
        let secondProcess = ATTNUserIdentity(
            identifiers: [:],
            visitorService: visitorService,
            persistentStorage: sharedStorage
        )
        let v2 = secondProcess.visitorId
        XCTAssertEqual(
            secondProcess.planUpdateUser(email: "user@example.com", phone: nil, pushToken: testToken, domain: testDomain),
            .rotatedAndReplaced,
            "Sync record confirmed under a rotated-away visitor id must not silence updateUser — otherwise V2 is never sent to the server"
        )
        XCTAssertNotEqual(secondProcess.visitorId, v2, "planUpdateUser must rotate when adoption declines")
    }

    /// Comment 2: identify() can pre-seed local state that fools the retry decision.
    /// Repro: updateUser(A) syncs under V1 → record=(A, token, domain, V1), local={email:A}.
    /// identify([email: B]) merges without rotating and without touching the record →
    /// local={email:B}. updateUser(B) then sees local matches incoming (B), sync doesn't
    /// match. Pre-fix returned `.retryWithoutRotation` and fired POST(B) under V1,
    /// attaching B's email to A's visitor id server-side. After the fix, the sync record's
    /// identity (A) differs from the incoming identity (B), so the plan rotates + replaces.
    func testPlanUpdateUser_identifyPreseedsDifferentIdentity_rotates() {
        let (identity, _) = makeIsolatedIdentity(identifiers: [ATTNIdentifierType.email: "a@example.com"])
        identity.recordSuccessfulSync(email: "a@example.com", phone: nil, pushToken: testToken, domain: testDomain, visitorId: identity.visitorId)
        let visitorIdUnderA = identity.visitorId
        // identify() bypasses the sync protocol: mutates local, no rotation, no record update.
        identity.mergeIdentifiers([ATTNIdentifierType.email: "b@example.com"])

        XCTAssertEqual(
            identity.planUpdateUser(email: "b@example.com", phone: nil, pushToken: testToken, domain: testDomain),
            .rotatedAndReplaced,
            "identify() pre-seeding a DIFFERENT identity must not let the retry-without-rotation branch attach B to A's visitor id"
        )
        XCTAssertNotEqual(identity.visitorId, visitorIdUnderA)
        XCTAssertEqual(identity.identifiers[ATTNIdentifierType.email] as? String, "b@example.com")
    }

    /// Comment 2 counter-check: identify() writing a SUPERSET (added clientUserId, same
    /// email/phone) must still allow retry-without-rotation for the sync-record identity.
    /// This pins that the fix keys off email/phone equality, not "any local write since sync."
    func testPlanUpdateUser_identifyAddsCustomKeyOnly_retryStillRotates() {
        // With an extra clientUserId in local, identifiersMatchLocked's count check
        // already forces rotation. This is the pre-existing "extra identifier stored"
        // path — reasserting so the Comment 2 fix doesn't accidentally weaken it.
        let (identity, _) = makeIsolatedIdentity(identifiers: [ATTNIdentifierType.email: "a@example.com"])
        identity.recordSuccessfulSync(email: "a@example.com", phone: nil, pushToken: testToken, domain: testDomain, visitorId: identity.visitorId)
        identity.mergeIdentifiers([ATTNIdentifierType.clientUserId: "cid-1"])
        let visitorIdBefore = identity.visitorId

        XCTAssertEqual(
            identity.planUpdateUser(email: "a@example.com", phone: nil, pushToken: testToken, domain: testDomain),
            .rotatedAndReplaced
        )
        XCTAssertNotEqual(identity.visitorId, visitorIdBefore)
    }

    /// Comment 3: logout after relaunch — cold launch adopts nothing (no matching sync
    /// tuple) yet local is empty. Pre-fix returned `.retryWithoutRotation` and fired
    /// detach without rotation, so the persisted visitor id kept flowing under A on
    /// every subsequent event. Now every non-skip planClearUser rotates.
    func testPlanClearUser_coldLaunchAfterSyncedUpdate_rotatesOnLogout() {
        let sharedStorage = ATTNPersistentStorageMock()
        let visitorService = ATTNVisitorService(
            persistentStorage: sharedStorage,
            logger: Logger(OSLog.disabled)
        )
        // First launch: updateUser(A) confirmed.
        let firstLaunch = ATTNUserIdentity(
            identifiers: [ATTNIdentifierType.email: "a@example.com"],
            visitorService: visitorService,
            persistentStorage: sharedStorage
        )
        firstLaunch.recordSuccessfulSync(email: "a@example.com", phone: nil, pushToken: testToken, domain: testDomain, visitorId: firstLaunch.visitorId)
        let visitorIdUnderA = firstLaunch.visitorId

        // Second launch: local is empty (in-memory only), visitor id persisted so it
        // still equals V1. clearUser() must rotate — the server still associates V1↔A.
        let secondLaunch = ATTNUserIdentity(
            identifiers: [:],
            visitorService: visitorService,
            persistentStorage: sharedStorage
        )
        XCTAssertEqual(secondLaunch.visitorId, visitorIdUnderA,
                       "precondition: visitor id survives relaunch")

        XCTAssertEqual(
            secondLaunch.planClearUser(pushToken: testToken, domain: testDomain),
            .rotatedAndReplaced
        )
        XCTAssertNotEqual(secondLaunch.visitorId, visitorIdUnderA,
                          "cold-launch logout must rotate; otherwise every subsequent event still uses V1, which the server associates with A")
    }
}
