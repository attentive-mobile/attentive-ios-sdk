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

    func testPlanClearUser_emptyLocalAndNoSyncRecord_returnsRetry() {
        // Fresh device with a push token but no confirmed sync yet: the server MIGHT have
        // the token attached to a previous user from before the SDK was upgraded, or from a
        // prior process where /user-update never completed. Return retry so caller detaches.
        let (identity, _) = makeIsolatedIdentity()
        let visitorIdBefore = identity.visitorId

        XCTAssertEqual(identity.planClearUser(pushToken: testToken, domain: testDomain), .retryWithoutRotation)
        XCTAssertEqual(identity.visitorId, visitorIdBefore,
                       "retry path must not rotate visitorId — retries reuse the same identity")
    }

    func testPlanClearUser_emptyLocalAndMatchingSyncRecord_returnsSkip() {
        // After a successful clearUser, planClearUser sees local empty and sync = empty for
        // the same push token. This is the "true no-op" case the Aero fanout depends on.
        let (identity, _) = makeIsolatedIdentity()
        identity.recordSuccessfulSync(email: nil, phone: nil, pushToken: testToken, domain: testDomain)
        let visitorIdBefore = identity.visitorId

        XCTAssertEqual(identity.planClearUser(pushToken: testToken, domain: testDomain), .skip)
        XCTAssertEqual(identity.visitorId, visitorIdBefore)
    }

    func testPlanClearUser_emptyLocalButSyncRecordForDifferentToken_returnsRetry() {
        // APNs rotated the device token. The prior sync applies to a different token; the
        // new one has not been detached server-side yet. Must retry.
        let (identity, _) = makeIsolatedIdentity()
        identity.recordSuccessfulSync(email: nil, phone: nil, pushToken: "old-token", domain: testDomain)

        XCTAssertEqual(identity.planClearUser(pushToken: "new-token", domain: testDomain), .retryWithoutRotation)
    }

    func testPlanClearUser_emptyLocalButSyncRecordNonEmpty_returnsRetry() {
        // Server last confirmed the token attached to email X. Local was cleared (fresh
        // process init, or identify() was never called this launch), but the server still
        // thinks the user is attached. Must detach.
        let (identity, _) = makeIsolatedIdentity()
        identity.recordSuccessfulSync(email: "user@example.com", phone: nil, pushToken: testToken, domain: testDomain)

        XCTAssertEqual(identity.planClearUser(pushToken: testToken, domain: testDomain), .retryWithoutRotation)
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
        identity.recordSuccessfulSync(email: "user@example.com", phone: "+15551234567", pushToken: testToken, domain: testDomain)
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
        identity.recordSuccessfulSync(email: "user@example.com", phone: "+15551234567", pushToken: "old-token", domain: testDomain)

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
        identity.recordSuccessfulSync(email: "user@example.com", phone: "+15551234567", pushToken: testToken, domain: testDomain)

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
        firstLaunch.recordSuccessfulSync(email: "user@example.com", phone: "+15551234567", pushToken: testToken, domain: testDomain)

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
        firstLaunch.recordSuccessfulSync(email: nil, phone: nil, pushToken: testToken, domain: testDomain)

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
        identity.recordSuccessfulSync(email: "user@example.com", phone: nil, pushToken: testToken, domain: testDomain)
        identity.recordSuccessfulSync(email: nil, phone: nil, pushToken: testToken, domain: testDomain)

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
        firstLaunch.recordSuccessfulSync(email: "user@example.com", phone: "+15551234567", pushToken: testToken, domain: testDomain)

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
        firstLaunch.recordSuccessfulSync(email: "old@example.com", phone: "+15551234567", pushToken: testToken, domain: testDomain)

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
        identity.recordSuccessfulSync(email: "user@example.com", phone: "+15551234567", pushToken: testToken, domain: "old-domain")

        XCTAssertEqual(
            identity.planUpdateUser(email: "user@example.com", phone: "+15551234567", pushToken: testToken, domain: "new-domain"),
            .retryWithoutRotation,
            "Domain change must invalidate the sync record — the new company hasn't confirmed this identity"
        )
    }

    func testPlanClearUser_domainChanged_returnsRetry() {
        // Same shape as the updateUser variant. A detach confirmed against old-domain must
        // not silence a subsequent clearUser after a domain switch: the new company still
        // has the push token attached (or, more precisely, has never been told to detach).
        let (identity, _) = makeIsolatedIdentity()
        identity.recordSuccessfulSync(email: nil, phone: nil, pushToken: testToken, domain: "old-domain")

        XCTAssertEqual(
            identity.planClearUser(pushToken: testToken, domain: "new-domain"),
            .retryWithoutRotation
        )
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
        firstLaunch.recordSuccessfulSync(email: "user@example.com", phone: nil, pushToken: testToken, domain: testDomain)

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
}
