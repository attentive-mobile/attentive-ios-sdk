//
//  ATTNUserIdentityTests.swift
//  attentive-ios-sdk Tests
//
//  Created by Vladimir - Work on 2024-06-04.
//

import XCTest
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
        runConcurrently(iterations: 200, timeout: 15, queueLabels: ["writer", "reader"]) { i, queueIndex in
            if queueIndex == 0 {
                identity.mergeIdentifiers([ATTNIdentifierType.email: "user\(i)@test.com"])
            } else {
                _ = identity.identifiers
                _ = identity.visitorId
            }
        }
    }

    func testClearUser_concurrentClearAndMerge_doesNotCrash() {
        let identity = ATTNUserIdentity()
        // Iteration count kept low because clearUser() does a synchronous
        // UserDefaults write per call; 20×2 racing calls is plenty to surface
        // a missing-lock crash without blowing CI's timeout budget on disk I/O.
        runConcurrently(iterations: 20, timeout: 20, queueLabels: ["merge", "clear"]) { i, queueIndex in
            if queueIndex == 0 {
                identity.mergeIdentifiers([ATTNIdentifierType.email: "user\(i)@test.com"])
            } else {
                identity.clearUser()
            }
        }
    }
}
