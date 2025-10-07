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
    // Reset the creative state using the shared state manager.
    ATTNCreativeStateManager.shared.updateState(.closed)
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
    XCTAssertTrue(apiSpy.domainWasSet)
    XCTAssertTrue(apiSpy.sendUserIdentityWasCalled)

    XCTAssertEqual(apiSpy.domain, newDomain)
  }

  func testUpdateDomain_sameDomain_willNotUpdateAPIDomainProperty() {
    XCTAssertFalse(apiSpy.updateDomainWasCalled)
    XCTAssertEqual(apiSpy.domain, testDomain)

    sut.update(domain: testDomain)

    XCTAssertFalse(apiSpy.updateDomainWasCalled)
    XCTAssertFalse(apiSpy.domainWasSet)
    XCTAssertFalse(apiSpy.sendUserIdentityWasCalled)

    XCTAssertEqual(apiSpy.domain, testDomain)
  }

  func testUpdateDomain_newDomain_willUpdateCreativeURL() {
    XCTAssertNotEqual(creativeUrlProviderSpy.usedDomain, newDomain)

    sut.update(domain: newDomain)

    XCTAssertEqual(apiSpy.domain, newDomain)

    let urlBuiltExpectation = expectation(description: "Creative URL should be built")
    creativeUrlProviderSpy.buildCompanyCreativeUrlExpectation = urlBuiltExpectation

    sut.trigger(UIView())
    wait(for: [urlBuiltExpectation], timeout: 5.0)

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

    let urlBuiltExpectation = expectation(description: "Creative URL should be built")
    creativeUrlProviderSpy.buildCompanyCreativeUrlExpectation = urlBuiltExpectation

    sut.trigger(UIView(), creativeId: creativeId, handler: nil)
    wait(for: [urlBuiltExpectation], timeout: 5.0)

    XCTAssertTrue(creativeUrlProviderSpy.buildCompanyCreativeUrlWasCalled)
    XCTAssertEqual(creativeUrlProviderSpy.usedCreativeId, creativeId)
  }

  func testSkipFatigue_whenEnvValueIsPassed_ShouldBeTrue() {
    ProcessInfo.swizzleEnvironment()
    let creativeId = "123456"
    sut = ATTNSDK(api: apiSpy, urlBuilder: creativeUrlProviderSpy)

    let urlBuiltExpectation = expectation(description: "Creative URL should be built")
    creativeUrlProviderSpy.buildCompanyCreativeUrlExpectation = urlBuiltExpectation

    sut.trigger(UIView(), creativeId: creativeId)
    wait(for: [urlBuiltExpectation], timeout: 5.0)

    XCTAssertTrue(creativeUrlProviderSpy.buildCompanyCreativeUrlWasCalled)
    XCTAssertEqual(creativeUrlProviderSpy.usedCreativeId, creativeId)
  }

  func testIsCreativeOpen_whenThereAreTwoSDKInstancesAndBothTriggersCreative_ShouldNotLaunchASecondCreative() {
    ATTNCreativeStateManager.shared.updateState(.closed)
    let secondCreativeUrlProviderSpy = ATTNCreativeUrlProviderSpy()
    let secondSdk = ATTNSDK(api: apiSpy, urlBuilder: secondCreativeUrlProviderSpy)

    XCTAssertFalse(ATTNCreativeStateManager.shared.getState() == .open, "The value should be false")

    let firstCreativeBuiltExpectation = expectation(description: "First creative URL should be built")
    creativeUrlProviderSpy.buildCompanyCreativeUrlExpectation = firstCreativeBuiltExpectation
    sut.trigger(UIView())
    wait(for: [firstCreativeBuiltExpectation], timeout: 5.0)
    XCTAssertTrue(creativeUrlProviderSpy.buildCompanyCreativeUrlWasCalled, "Creative url should be built")

    // Use an inverted expectation to assert that its URL building is not called.
    let secondCreativeNotBuiltExpectation = expectation(description: "Second creative URL should not be built")
    secondCreativeNotBuiltExpectation.isInverted = true
    secondCreativeUrlProviderSpy.buildCompanyCreativeUrlExpectation = secondCreativeNotBuiltExpectation

    secondSdk.trigger(UIView())
    wait(for: [secondCreativeNotBuiltExpectation], timeout: 1.0)
    XCTAssertFalse(secondCreativeUrlProviderSpy.buildCompanyCreativeUrlWasCalled, "Creative url should not be built")

    addTeardownBlock {
      ATTNCreativeStateManager.shared.updateState(.closed)
    }
  }

  func testEscapeJSONDictionary_shouldEscapeQuotesAndSlashes() {
      // Given
      let input: [String: Any] = [
        "attentive_message_body": #"You heard that right ... shop these "no size" required must-haves and save big!"/test"#,
        "plain": "Hello"
      ]

      // When
      let escaped = sut.escapeJSONDictionary(input)

      // Then
      let result = escaped["attentive_message_body"] as? String
      XCTAssertNotNil(result)
      XCTAssertTrue(result!.contains("\\\""), "Quotes should be escaped")
      XCTAssertTrue(result!.contains("\\/"), "Forward slashes should be escaped")
      XCTAssertEqual(escaped["plain"] as? String, "Hello")
    }

    func testEscapeJSONDictionary_shouldHandleNestedDictionary() {
      // Given
      let input: [String: Any] = [
        "outer": [
          "inner": #"He said "hello"/world"#
        ]
      ]

      // When
      let escaped = sut.escapeJSONDictionary(input)
      let nested = (escaped["outer"] as? [String: Any])?["inner"] as? String

      // Then
      XCTAssertNotNil(nested)
      XCTAssertTrue(nested!.contains("\\\""))
      XCTAssertTrue(nested!.contains("\\/"))
    }

    func testEscapeJSONArray_shouldEscapeStringsAndNestedStructures() {
      // Given
      let input: [Any] = [
              "Hello \"friend\"/world",
              ["nested": "A \"quote\"/slash"],
              ["array", ["nested \"quote\""]]
          ]

      // When
      let escaped = sut.escapeJSONArray(input)

      // Then
      let first = escaped.first as? String
      XCTAssertTrue(first?.contains("\\\"") ?? false)
      XCTAssertTrue(first?.contains("\\/") ?? false)

      if let nestedDict = escaped[1] as? [String: Any],
         let inner = nestedDict["nested"] as? String {
        XCTAssertTrue(inner.contains("\\\""))
        XCTAssertTrue(inner.contains("\\/"))
      }

      if let nestedArray = (escaped[2] as? [Any])?.last as? [Any],
         let nestedString = nestedArray.first as? String {
        XCTAssertTrue(nestedString.contains("\\\""))
      }
    }

    func testEscapeJSONDictionary_shouldLeaveNumbersAndBooleansUnchanged() {
      // Given
      let input: [String: Any] = [
        "number": 123,
        "bool": true,
        "double": 1.5
      ]

      // When
      let escaped = sut.escapeJSONDictionary(input)

      // Then
      XCTAssertEqual(escaped["number"] as? Int, 123)
      XCTAssertEqual(escaped["bool"] as? Bool, true)
      XCTAssertEqual(escaped["double"] as? Double, 1.5)
    }

}

