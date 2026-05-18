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
        let group = DispatchGroup()
        let queue = DispatchQueue(label: "concurrent", attributes: .concurrent)
        for _ in 0..<200 {
            group.enter()
            queue.async {
                ATTNEventTracker.setup(with: sdk)
                group.leave()
            }
            group.enter()
            queue.async {
                _ = ATTNEventTracker.sharedInstance()
                group.leave()
            }
        }
        let result = group.wait(timeout: .now() + 5)
        XCTAssertEqual(result, .success)
        XCTAssertNotNil(ATTNEventTracker.sharedInstance())
    }
}
