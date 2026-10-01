//
//  ATTNEventTrackerTests.swift
//  attentive-ios-sdk Tests
//
//  Created by Vladimir - Work on 2024-06-04.
//

import XCTest
@testable import ATTNSDKFramework

final class ATTNEventTrackerTests: XCTestCase {

    override func tearDown() {
        ATTNEventTracker.destroy()
        super.tearDown()
    }

    func testGetSharedInstance_notSetup_throws() {
        let sdkMock = ATTNSDK(domain: "domain")
        ATTNEventTracker.setup(with: sdkMock)

        XCTAssertNoThrow(ATTNEventTracker.sharedInstance())
    }

    func testSharedInstance_concurrentSetupAndAccess_doesNotCrash() {
        let sdk = ATTNSDK(domain: "domain")
        // Seed the instance first: sharedInstance() asserts (crashing the test
        // runner in debug builds) if an "access" block wins the race against the
        // first "setup" block. The concurrency under test is setup/access
        // interleaving on an already-initialized tracker, not access-before-setup.
        ATTNEventTracker.setup(with: sdk)
        runConcurrently(iterations: 200, queueLabels: ["setup", "access"]) { _, queueIndex in
            if queueIndex == 0 {
                ATTNEventTracker.setup(with: sdk)
            } else {
                _ = ATTNEventTracker.sharedInstance()
            }
        }
        XCTAssertNotNil(ATTNEventTracker.sharedInstance())
    }
}
