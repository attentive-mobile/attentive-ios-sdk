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

    // -- planClearUser ---------------------------------------------------------------

    func testPlanClearUser_emptyLocalAndNoSyncRecord_returnsRetry() {
        // Fresh device with a push token but no confirmed sync yet: the server MIGHT have
        // the token attached to a previous user from before the SDK was upgraded, or from a
        // prior process where /user-update never completed. Return retry so caller detaches.
        let (identity, _) = makeIsolatedIdentity()
        let visitorIdBefore = identity.visitorId

        XCTAssertEqual(identity.planClearUser(pushToken: testToken), .retryWithoutRotation)
        XCTAssertEqual(identity.visitorId, visitorIdBefore,
                       "retry path must not rotate visitorId — retries reuse the same identity")
    }

    func testPlanClearUser_emptyLocalAndMatchingSyncRecord_returnsSkip() {
        // After a successful clearUser, planClearUser sees local empty and sync = empty for
        // the same push token. This is the "true no-op" case the Aero fanout depends on.
        let (identity, _) = makeIsolatedIdentity()
        identity.recordSuccessfulSync(email: nil, phone: nil, pushToken: testToken)
        let visitorIdBefore = identity.visitorId

        XCTAssertEqual(identity.planClearUser(pushToken: testToken), .skip)
        XCTAssertEqual(identity.visitorId, visitorIdBefore)
    }

    func testPlanClearUser_emptyLocalButSyncRecordForDifferentToken_returnsRetry() {
        // APNs rotated the device token. The prior sync applies to a different token; the
        // new one has not been detached server-side yet. Must retry.
        let (identity, _) = makeIsolatedIdentity()
        identity.recordSuccessfulSync(email: nil, phone: nil, pushToken: "old-token")

        XCTAssertEqual(identity.planClearUser(pushToken: "new-token"), .retryWithoutRotation)
    }

    func testPlanClearUser_emptyLocalButSyncRecordNonEmpty_returnsRetry() {
        // Server last confirmed the token attached to email X. Local was cleared (fresh
        // process init, or identify() was never called this launch), but the server still
        // thinks the user is attached. Must detach.
        let (identity, _) = makeIsolatedIdentity()
        identity.recordSuccessfulSync(email: "user@example.com", phone: nil, pushToken: testToken)

        XCTAssertEqual(identity.planClearUser(pushToken: testToken), .retryWithoutRotation)
    }

    func testPlanClearUser_nonEmptyLocal_returnsRotatedAndReplaced() {
        let (identity, _) = makeIsolatedIdentity(identifiers: [ATTNIdentifierType.email: "user@example.com"])
        let visitorIdBefore = identity.visitorId

        XCTAssertEqual(identity.planClearUser(pushToken: testToken), .rotatedAndReplaced)
        XCTAssertEqual(identity.identifiers.count, 0)
        XCTAssertNotEqual(identity.visitorId, visitorIdBefore)
    }

    // -- planUpdateUser --------------------------------------------------------------

    func testPlanUpdateUser_localDiffers_returnsRotatedAndReplaced() {
        let (identity, _) = makeIsolatedIdentity()
        let visitorIdBefore = identity.visitorId

        XCTAssertEqual(
            identity.planUpdateUser(email: "user@example.com", phone: "+15551234567", pushToken: testToken),
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
        identity.recordSuccessfulSync(email: "user@example.com", phone: "+15551234567", pushToken: testToken)
        let visitorIdBefore = identity.visitorId

        XCTAssertEqual(
            identity.planUpdateUser(email: "user@example.com", phone: "+15551234567", pushToken: testToken),
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
            identity.planUpdateUser(email: "user@example.com", phone: "+15551234567", pushToken: testToken),
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
        identity.recordSuccessfulSync(email: "user@example.com", phone: "+15551234567", pushToken: "old-token")

        XCTAssertEqual(
            identity.planUpdateUser(email: "user@example.com", phone: "+15551234567", pushToken: "new-token"),
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
            identity.planUpdateUser(email: "user@example.com", phone: "+15551234567", pushToken: testToken),
            .rotatedAndReplaced
        )
        XCTAssertNil(identity.identifiers[ATTNIdentifierType.clientUserId])
    }

    func testPlanUpdateUser_normalizesWhitespaceForCompareAndStorage() {
        // Whitespace on inputs must collapse — both for the local-equality check and for
        // what gets stored, so subsequent same-value calls hit .skip.
        let (identity, _) = makeIsolatedIdentity()
        _ = identity.planUpdateUser(email: "  user@example.com  ", phone: " +15551234567 ", pushToken: testToken)
        identity.recordSuccessfulSync(email: "user@example.com", phone: "+15551234567", pushToken: testToken)

        XCTAssertEqual(identity.identifiers[ATTNIdentifierType.email] as? String, "user@example.com",
                       "planUpdateUser must store the normalized value, not the raw whitespaced input")
        XCTAssertEqual(
            identity.planUpdateUser(email: "user@example.com", phone: "+15551234567", pushToken: testToken),
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
        firstLaunch.recordSuccessfulSync(email: "user@example.com", phone: "+15551234567", pushToken: testToken)

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
            secondLaunch.planUpdateUser(email: "user@example.com", phone: "+15551234567", pushToken: testToken),
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
        firstLaunch.recordSuccessfulSync(email: nil, phone: nil, pushToken: testToken)

        let secondLaunch = ATTNUserIdentity(
            identifiers: [:],
            visitorService: visitorService,
            persistentStorage: sharedStorage
        )
        XCTAssertEqual(
            secondLaunch.planClearUser(pushToken: testToken),
            .skip,
            "Persisted detach confirmation must survive so a subsequent clearUser is a no-op"
        )
    }

    func testRecordSuccessfulSync_overwritesPreviousEmailWithNil() {
        // updateUser(email=A) succeeds, then clearUser() succeeds. The sync record must now
        // reflect the empty state — not still hold email=A.
        let (identity, _) = makeIsolatedIdentity()
        identity.recordSuccessfulSync(email: "user@example.com", phone: nil, pushToken: testToken)
        identity.recordSuccessfulSync(email: nil, phone: nil, pushToken: testToken)

        XCTAssertEqual(
            identity.planClearUser(pushToken: testToken),
            .skip,
            "recordSuccessfulSync(nil, nil, …) must clear the previously-recorded email"
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
