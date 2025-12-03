//
//  ATTNUserAgentBuilderTests.swift
//  attentive-ios-sdk Tests
//
//  Created by Vladimir - Work on 2024-06-04.
//

import XCTest
@testable import ATTNSDKFramework

final class ATTNUserAgentBuilderTests: XCTestCase {
    private var appInfoMock: ATTNAppInfoMock!
    private var sut: ATTNUserAgentBuilder!

    override func setUp() {
        super.setUp()
        appInfoMock = ATTNAppInfoMock()
        sut = ATTNUserAgentBuilder(appInfo: appInfoMock)
    }

    override func tearDown() {
        appInfoMock = nil
        sut = nil
        super.tearDown()
    }

    func testBuildUserAgent_appInfoReturnsAllValues_userAgentIsFormattedCorrectly() {
        XCTAssertEqual("appName-Value/appVersionValue.appBuildValue (deviceModelNameValue; devicePlatformValue deviceOsVersionValue) sdkNameValue/sdkVersionValue", sut.buildUserAgent())
    }
}
