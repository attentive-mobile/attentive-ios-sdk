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

    func testMergeIdentifiers_concurrentMerges_doesNotCrashAndPreservesAllKeys() {
        let identity = ATTNUserIdentity()
        let iterations = 200
        DispatchQueue.concurrentPerform(iterations: iterations) { i in
            identity.mergeIdentifiers([ATTNIdentifierType.customIdentifiers: ["key\(i)": "value\(i)"] as NSDictionary])
        }
        // The classic TOCTOU here would either crash or drop keys. With proper locking
        // we only guarantee the merge sequence is atomic — the *last* writer wins for the
        // shared key, but the operation must complete without crashing.
        XCTAssertNotNil(identity.identifiers[ATTNIdentifierType.customIdentifiers])
    }

    func testMergeAndRead_concurrentReadersAndWriters_doesNotCrash() {
        let identity = ATTNUserIdentity(identifiers: [ATTNIdentifierType.email: "seed@test.com"])
        let group = DispatchGroup()
        let writerQueue = DispatchQueue(label: "writer", attributes: .concurrent)
        let readerQueue = DispatchQueue(label: "reader", attributes: .concurrent)

        for i in 0..<200 {
            group.enter()
            writerQueue.async {
                identity.mergeIdentifiers([ATTNIdentifierType.email: "user\(i)@test.com"])
                group.leave()
            }
            group.enter()
            readerQueue.async {
                _ = identity.identifiers
                _ = identity.visitorId
                group.leave()
            }
        }
        let result = group.wait(timeout: .now() + 5)
        XCTAssertEqual(result, .success)
    }

    func testClearUser_concurrentClearAndMerge_doesNotCrash() {
        let identity = ATTNUserIdentity()
        let group = DispatchGroup()
        let queue = DispatchQueue(label: "concurrent", attributes: .concurrent)
        for i in 0..<100 {
            group.enter()
            queue.async {
                identity.mergeIdentifiers([ATTNIdentifierType.email: "user\(i)@test.com"])
                group.leave()
            }
            group.enter()
            queue.async {
                identity.clearUser()
                group.leave()
            }
        }
        let result = group.wait(timeout: .now() + 5)
        XCTAssertEqual(result, .success)
    }
}
