//
//  ATTNCustomEventTests.swift
//  attentive-ios-sdk Tests
//
//  Created by Vladimir - Work on 2024-06-04.
//

import XCTest
@testable import ATTNSDKFramework

final class ATTNCustomEventTests: XCTestCase {
    func testConstructor() {
        XCTAssertNoThrow(ATTNCustomEvent(type: "]", properties: ["k": "v"]))
        XCTAssertNoThrow(ATTNCustomEvent(type: "good", properties: ["k]": "v"]))

        XCTAssertNoThrow(ATTNCustomEvent(type: "", properties: ["k": "v"]))
        XCTAssertNoThrow(ATTNCustomEvent(type: "good", properties: [:]))
        XCTAssertNoThrow(ATTNCustomEvent(type: "good", properties: ["k": "v"]))
    }
}
