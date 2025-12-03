//
//  ATTNVisitorServiceTests.swift
//  attentive-ios-sdk Tests
//
//  Created by Vladimir - Work on 2024-06-04.
//

import XCTest
@testable import ATTNSDKFramework

final class ATTNVisitorServiceTests: XCTestCase {
    private var sut: ATTNVisitorService!

    override func setUp() {
        super.setUp()
        sut = ATTNVisitorService()
    }

    override func tearDown() {
        sut = nil
        super.tearDown()
    }

    func testGetVisitorId_returnedIdIsNotNilAndCorrectFormat() {
        XCTAssertFalse(sut.getVisitorId().isEmpty)
    }

    func testGetVisitorId_callGetVisitorIdTwice_returnsSameId() {
        let visitorId = sut.getVisitorId()
        XCTAssertFalse(sut.getVisitorId().isEmpty)
        XCTAssertEqual(visitorId, sut.getVisitorId())
    }

    func testCreateNewVisitorId_call_returnsNewId() {
        let oldVisitorId = sut.getVisitorId()
        let newVisitorId = sut.createNewVisitorId()

        XCTAssertNotEqual(oldVisitorId, newVisitorId)
    }

    func testCreateNewVisitorId_noVisitorIdHasBeenRetrievedYet_returnsId() {
        XCTAssertFalse(sut.createNewVisitorId().isEmpty)
    }

    func testCreateNewVisitorId_createThenGet_sameId() {
        let newVisitorId = sut.createNewVisitorId()
        XCTAssertEqual(newVisitorId, sut.getVisitorId())
    }
}
