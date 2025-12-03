//
//  ATTNParameterValidationTests.swift
//  attentive-ios-sdk Tests
//
//  Created by Vladimir - Work on 2024-06-04.
//

import XCTest
@testable import ATTNSDKFramework

final class ATTNParameterValidationTests: XCTestCase {
    private var sut: ATTNParameterValidation.Type!

    override func setUp() {
        super.setUp()
        sut = ATTNParameterValidation.self
    }

    override func tearDown() {
        sut = nil
        super.tearDown()
    }

    func testIsNotNil_givenNil_returnsFalse() {
        XCTAssertFalse(sut.isNotNil(nil))
    }

    func testIsNotNil_givenNotNil_returnsTrue() {
        XCTAssertTrue(sut.isNotNil(NSString()))
    }

    func testIsStringAndNotEmpty_givenNil_returnsFalse() {
        XCTAssertFalse(sut.isStringAndNotEmpty(nil))
    }

    func testIsStringAndNotEmpty_givenDictionary_returnsFalse() {
        XCTAssertFalse(sut.isStringAndNotEmpty([:] as NSDictionary))
    }

    func testIsStringAndNotEmpty_givenEmptyString_returnsFalse() {
        XCTAssertFalse(sut.isStringAndNotEmpty("" as NSObject))
    }

    func testIsStringAndNotEmpty_givenNonEmptyString_returnsTrue() {
        XCTAssertTrue(sut.isStringAndNotEmpty("notEmpty" as NSObject))
    }

    func testVerifyStringOrNil_givenNil_succeeds() {
        XCTAssertNoThrow(sut.verifyStringOrNil(nil, inputName: "inputNameValue"))
    }

    func testVerifyStringOrNil_givenDictionary_doesNotThrow() {
        XCTAssertNoThrow(sut.verifyStringOrNil(["hi": "hello"] as NSDictionary, inputName: "inputNameValue"))
    }

    func testVerifyStringOrNil_givenEmptyString_doesNotThrow() {
        XCTAssertNoThrow(sut.verifyStringOrNil("" as NSObject, inputName: "inputNameValue"))
    }

    func testVerifyStringOrNil_givenNonEmptyString_succeeds() {
        XCTAssertNoThrow(sut.verifyStringOrNil("notEmpty" as NSObject, inputName: "inputNameValue"))
    }

    func testVerify1DStringDictionaryOrNil_givenNil_succeeds() {
        XCTAssertNoThrow(sut.verify1DStringDictionaryOrNil(nil, inputName: "inputNameValue"))
    }

    func testVerify1DStringDictionaryOrNil_givenEmptyDictionary_succeeds() {
        XCTAssertNoThrow(sut.verify1DStringDictionaryOrNil([:] as NSDictionary, inputName: "inputNameValue"))
    }

    func testVerify1DStringDictionaryOrNil_givenNonEmptyDictionary_succeeds() {
        XCTAssertNoThrow(sut.verify1DStringDictionaryOrNil(["someKey": "someValue"] as NSDictionary, inputName: "inputNameValue"))
    }
}
