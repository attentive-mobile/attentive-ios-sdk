//
//  ATTNCreativeUrlFormatterTests.swift
//  attentive-ios-sdk Tests
//
//  Created by Vladimir - Work on 2024-06-04.
//

import XCTest
@testable import ATTNSDKFramework

final class ATTNCreativeUrlFormatterTests: XCTestCase {
  private let testDomain = "testDomain"
  private var sut: ATTNCreativeUrlProvider!
  private var appInfo: ATTNAppInfo!

  override func setUp() {
    super.setUp()
    appInfo = .init()
    sut = ATTNCreativeUrlProvider()
  }

  override func tearDown() {
    appInfo = nil
    sut = nil
    super.tearDown()
  }

  func testBuildCompanyCreativeUrlForDomain_productionMode_buildsProdUrl() {
    let userIdentity = ATTNUserIdentity(identifiers: [:])
    let config = ATTNCreativeUrlConfig(
      domain: testDomain,
      creativeId: nil,
      skipFatigue: false,
      mode: "production",
      userIdentity: userIdentity
    )

    let url = sut.buildCompanyCreativeUrl(configuration: config)

    let expectedUrl = "https://creatives.attn.tv/mobile-apps/index.html?domain=testDomain&vid=\(userIdentity.visitorId)&sdkVersion=\(appInfo.getSdkVersion())&sdkName=attentive-ios-sdk"

    XCTAssertEqual(expectedUrl, url)
  }

  func testBuildCompanyCreativeUrlForDomain_productionMode_buildsDebugUrl() {
    let userIdentity = ATTNUserIdentity(identifiers: [:])
    let config = ATTNCreativeUrlConfig(
      domain: testDomain,
      creativeId: nil,
      skipFatigue: false,
      mode: "debug",
      userIdentity: userIdentity
    )

    let url = sut.buildCompanyCreativeUrl(configuration: config)

    let expectedUrl = "https://creatives.attn.tv/mobile-apps/index.html?domain=testDomain&debug=matter-trip-grass-symbol&vid=\(userIdentity.visitorId)&sdkVersion=\(appInfo.getSdkVersion())&sdkName=attentive-ios-sdk"

    XCTAssertEqual(expectedUrl, url)
  }

  func testBuildCompanyCreativeUrlForDomain_withUserIdentifiers_buildsUrlWithIdentifierQueryParams() {
    let userIdentity = ATTNTestEventUtils.buildUserIdentity()
    let config = ATTNCreativeUrlConfig(
      domain: testDomain,
      creativeId: nil,
      skipFatigue: false,
      mode: "production",
      userIdentity: userIdentity
    )

    let url = sut.buildCompanyCreativeUrl(configuration: config)

    let expectedUrl = "https://creatives.attn.tv/mobile-apps/index.html?domain=testDomain&vid=\(userIdentity.visitorId)&cuid=someClientUserId&p=+14156667777&e=someEmail@email.com&kid=someKlaviyoId&sid=someShopifyId&cstm=%7B%22customId%22:%22customIdValue%22%7D&sdkVersion=\(appInfo.getSdkVersion())&sdkName=attentive-ios-sdk"

    XCTAssertEqual(expectedUrl, url)
  }

  func testBuildCompanyCreativeUrlForDomain_productionMode_buildsUrlWithSdkDetails() {
    let userIdentity = ATTNUserIdentity(identifiers: [:])

    let config = ATTNCreativeUrlConfig(
      domain: testDomain,
      creativeId: nil,
      skipFatigue: false,
      mode: "production",
      userIdentity: userIdentity
    )

    let url = sut.buildCompanyCreativeUrl(configuration: config)

    let expectedUrl = "https://creatives.attn.tv/mobile-apps/index.html?domain=testDomain&vid=\(userIdentity.visitorId)&sdkVersion=\(ATTNConstants.sdkVersion)&sdkName=attentive-ios-sdk"

    XCTAssertEqual(expectedUrl, url)
  }

  func testBuildCompanyCreativeUrlForDomain_withSkipFatigue_buildsUrlWithSkipFatigue() {
    let userIdentity = ATTNUserIdentity(identifiers: [:])

    let config = ATTNCreativeUrlConfig(
      domain: testDomain,
      creativeId: nil,
      skipFatigue: true,
      mode: "production",
      userIdentity: userIdentity
    )

    let url = sut.buildCompanyCreativeUrl(configuration: config)

    let expectedUrl = "https://creatives.attn.tv/mobile-apps/index.html?domain=testDomain&vid=\(userIdentity.visitorId)&sdkVersion=\(ATTNConstants.sdkVersion)&sdkName=attentive-ios-sdk&skipFatigue=true"

    XCTAssertEqual(expectedUrl, url)
  }

  func testBuildCompanyCreativeUrlForDomain_withCreativeId_buildsUrlWithCreativeId() {
    let userIdentity = ATTNUserIdentity(identifiers: [:])

    let config = ATTNCreativeUrlConfig(
      domain: testDomain,
      creativeId: "1234567",
      skipFatigue: false,
      mode: "production",
      userIdentity: userIdentity
    )

    let url = sut.buildCompanyCreativeUrl(configuration: config)

    let expectedUrl = "https://creatives.attn.tv/mobile-apps/index.html?domain=testDomain&vid=\(userIdentity.visitorId)&sdkVersion=\(ATTNConstants.sdkVersion)&sdkName=attentive-ios-sdk&attn_creative_id=1234567"

    XCTAssertEqual(expectedUrl, url)
  }
}
