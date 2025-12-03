//
//  ATTNProductViewEventTests.swift
//  attentive-ios-sdk Tests
//
//  Created by Vladimir - Work on 2024-07-11.
//

import Foundation

import XCTest
@testable import ATTNSDKFramework

final class ATTNProductViewEventTests: XCTestCase {
    func testProductView_GivenData_ShouldBuildURL() {
        let item = ATTNTestEventUtils.buildItem()
        let productView = ATTNProductViewEvent(items: [item])
        XCTAssertFalse(productView.eventRequests.isEmpty)
        XCTAssertNil(productView.eventRequests.first?.deeplink)
    }

    func testProductView_GivenData_ShouldBuildURLWithRequestURL() {
        let item = ATTNTestEventUtils.buildItem()
        let productView = ATTNProductViewEvent(items: [item], deeplink: "https://mydeeplink.com/products/32432423")
        XCTAssertFalse(productView.eventRequests.isEmpty)
        let requestURL = productView.eventRequests.first?.deeplink as? String
        XCTAssertNotNil(requestURL)
        XCTAssertFalse(requestURL?.isEmpty ?? true)
    }
}
