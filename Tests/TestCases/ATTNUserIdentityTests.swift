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

    // MARK: MSDK-469 primitives — clearUserIfNeeded, switchIdentity

    func testClearUserIfNeeded_emptyStore_returnsFalseAndDoesNotRotate() {
        let identity = ATTNUserIdentity()
        let visitorIdBefore = identity.visitorId

        XCTAssertFalse(identity.clearUserIfNeeded(),
                       "clearUserIfNeeded should return false when there is nothing to clear")
        XCTAssertEqual(identity.visitorId, visitorIdBefore,
                       "clearUserIfNeeded must not rotate visitorId on the empty path")
    }

    func testClearUserIfNeeded_nonEmptyStore_returnsTrueClearsAndRotates() {
        let identity = ATTNUserIdentity(identifiers: [ATTNIdentifierType.email: "user@example.com"])
        let visitorIdBefore = identity.visitorId

        XCTAssertTrue(identity.clearUserIfNeeded(),
                      "clearUserIfNeeded should return true when identifiers were present")
        XCTAssertEqual(identity.identifiers.count, 0)
        XCTAssertNotEqual(identity.visitorId, visitorIdBefore,
                          "clearUserIfNeeded must rotate visitorId when it clears")
    }

    func testSwitchIdentity_matchesStored_returnsFalseAndDoesNotRotate() {
        let identity = ATTNUserIdentity(identifiers: [
            ATTNIdentifierType.email: "user@example.com",
            ATTNIdentifierType.phone: "+15551234567"
        ])
        let visitorIdBefore = identity.visitorId

        XCTAssertFalse(identity.switchIdentity(email: "user@example.com", phone: "+15551234567"),
                       "switchIdentity should return false when the incoming set exactly matches stored")
        XCTAssertEqual(identity.visitorId, visitorIdBefore,
                       "switchIdentity must not rotate visitorId on the match path")
        XCTAssertEqual(identity.identifiers.count, 2)
    }

    func testSwitchIdentity_differentEmail_returnsTrueReplacesAndRotates() {
        let identity = ATTNUserIdentity(identifiers: [
            ATTNIdentifierType.email: "first@example.com",
            ATTNIdentifierType.phone: "+15551234567"
        ])
        let visitorIdBefore = identity.visitorId

        XCTAssertTrue(identity.switchIdentity(email: "second@example.com", phone: "+15551234567"))
        XCTAssertEqual(identity.identifiers[ATTNIdentifierType.email] as? String, "second@example.com")
        XCTAssertNotEqual(identity.visitorId, visitorIdBefore)
    }

    func testSwitchIdentity_extraIdentifierPresent_dropsItAndRotates() {
        // clientUserId is not in the incoming {email, phone} set, so the count mismatch forces
        // the switch to run and the extra identifier gets replaced away — matching the
        // pre-MSDK-469 clearUserIdentifiers() + mergeIdentifiers() behavior.
        let identity = ATTNUserIdentity(identifiers: [
            ATTNIdentifierType.email: "user@example.com",
            ATTNIdentifierType.phone: "+15551234567",
            ATTNIdentifierType.clientUserId: "customer-123"
        ])
        let visitorIdBefore = identity.visitorId

        XCTAssertTrue(identity.switchIdentity(email: "user@example.com", phone: "+15551234567"),
                      "switchIdentity must run when the stored set has any extra identifier")
        XCTAssertNil(identity.identifiers[ATTNIdentifierType.clientUserId],
                     "switchIdentity should drop identifiers absent from the incoming set")
        XCTAssertNotEqual(identity.visitorId, visitorIdBefore)
    }

    func testSwitchIdentity_nilEmailAndPhoneOnEmptyStore_returnsFalse() {
        // Not a realistic public call (updateUser rejects the all-nil case upstream), but
        // pinning the primitive's contract: nil-nil against an empty store is a match.
        let identity = ATTNUserIdentity()
        let visitorIdBefore = identity.visitorId

        XCTAssertFalse(identity.switchIdentity(email: nil, phone: nil))
        XCTAssertEqual(identity.visitorId, visitorIdBefore)
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
