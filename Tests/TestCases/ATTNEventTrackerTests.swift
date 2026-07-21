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
