//
//  ATTNSDKTests.swift
//  attentive-ios-sdk Tests
//
//  Created by Vladimir - Work on 2024-06-13.
//

import XCTest
@testable import ATTNSDKFramework

final class ATTNSDKTests: XCTestCase {
  private var sut: ATTNSDK!
  private var apiSpy: ATTNAPISpy!
  private var creativeUrlProviderSpy: ATTNCreativeUrlProviderSpy!

  private let testDomain = "TEST_DOMAIN"
  private let newDomain = "NEW_DOMAIN"

  override func setUp() {
    super.setUp()
    creativeUrlProviderSpy = ATTNCreativeUrlProviderSpy()
    apiSpy = ATTNAPISpy(domain: testDomain)
    sut = ATTNSDK(api: apiSpy, urlBuilder: creativeUrlProviderSpy)
  }

  override func tearDown() {
    ATTNEventTracker.destroy()

    ProcessInfo.restoreOriginalEnvironment()

    creativeUrlProviderSpy = nil
    sut = nil
    apiSpy = nil

    super.tearDown()
  }

  func testUpdateDomain_newDomain_willUpdateAPIDomainProperty() {
    XCTAssertFalse(apiSpy.updateDomainWasCalled)
    XCTAssertEqual(apiSpy.domain, testDomain)

    sut.update(domain: newDomain)

    XCTAssertTrue(apiSpy.updateDomainWasCalled)
    XCTAssertTrue(apiSpy.domainWasSetted)
    XCTAssertTrue(apiSpy.sendUserIdentityWasCalled)
    
    XCTAssertEqual(apiSpy.domain, newDomain)
  }

  func testUpdateDomain_sameDomain_willNotUpdateAPIDomainProperty() {
    XCTAssertFalse(apiSpy.updateDomainWasCalled)
    XCTAssertEqual(apiSpy.domain, testDomain)

    sut.update(domain: testDomain)

    XCTAssertFalse(apiSpy.updateDomainWasCalled)
    XCTAssertFalse(apiSpy.domainWasSetted)
    XCTAssertFalse(apiSpy.sendUserIdentityWasCalled)

    XCTAssertEqual(apiSpy.domain, testDomain)
  }

  func testUpdateDomain_newDomain_willUpdateCreativeURL() {
    XCTAssertNotEqual(creativeUrlProviderSpy.usedDomain, newDomain)

    sut.update(domain: newDomain)

    XCTAssertEqual(apiSpy.domain, newDomain)

    sut.trigger(UIView())

    XCTAssertTrue(creativeUrlProviderSpy.buildCompanyCreativeUrlWasCalled)
    XCTAssertEqual(creativeUrlProviderSpy.usedDomain, newDomain)
  }

  func testUpdateDomain_newDomain_willBeReflectedOnEventTracking() {
    sut.update(domain: newDomain)

    ATTNEventTracker.setup(with: sut)

    ATTNEventTracker.sharedInstance()?.record(event: ATTNInfoEvent())

    XCTAssertTrue(apiSpy.sendEventWasCalled)

    let sdk = ATTNEventTracker.sharedInstance()?.getSdk()

    XCTAssertEqual(sdk?.getDomain(), newDomain)
  }

  func testSkipFatigue_whenTrue_willUpdateUrl() {
    let creativeId = "123456"
    sut.skipFatigueOnCreative = true

    sut.trigger(UIView(), creativeId: creativeId, handler: nil)

    XCTAssertTrue(creativeUrlProviderSpy.buildCompanyCreativeUrlWasCalled)
    XCTAssertEqual(creativeUrlProviderSpy.usedCreativeId, creativeId)
  }

  func testSkipFatigue_whenEnvValueIsPassed_ShouldBeTrue() {
    ProcessInfo.swizzleEnvironment()
    let creativeId = "123456"
    sut = ATTNSDK(api: apiSpy, urlBuilder: creativeUrlProviderSpy)

    sut.trigger(UIView(), creativeId: creativeId)

    XCTAssertTrue(creativeUrlProviderSpy.buildCompanyCreativeUrlWasCalled)
    XCTAssertEqual(creativeUrlProviderSpy.usedCreativeId, creativeId)
  }
}

