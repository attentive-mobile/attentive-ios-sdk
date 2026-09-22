//
//  ATTNTrackingConsentTests.swift
//  attentive-ios-sdk-frameworkTests
//

import XCTest
@testable import ATTNSDKFramework

final class ATTNTrackingConsentTests: XCTestCase {

    func testWireValue_accepted_isACCEPTED() {
        XCTAssertEqual(ATTNTrackingConsent.accepted.wireValue, "ACCEPTED")
    }

    func testWireValue_declined_isDECLINED() {
        XCTAssertEqual(ATTNTrackingConsent.declined.wireValue, "DECLINED")
    }

    func testWireValue_unspecified_isNil() {
        // .unspecified must not send the literal "UNSPECIFIED" on the wire — callers omit the
        // field entirely so the backend applies its own locale defaulting.
        XCTAssertNil(ATTNTrackingConsent.unspecified.wireValue)
    }

    func testRawValues_stableForObjCBridging() {
        // The Int raw values are the ObjC bridge contract. Never renumber — @objc consumers
        // may hold cached ordinals.
        XCTAssertEqual(ATTNTrackingConsent.unspecified.rawValue, 0)
        XCTAssertEqual(ATTNTrackingConsent.accepted.rawValue, 1)
        XCTAssertEqual(ATTNTrackingConsent.declined.rawValue, 2)
    }
}
