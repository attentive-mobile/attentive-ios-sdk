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
      // Escaping is no longer done - strings should remain unchanged
      XCTAssertFalse(result!.contains("\\\""), "Quotes should NOT be escaped")
      XCTAssertFalse(result!.contains("\\/"), "Forward slashes should NOT be escaped")
      XCTAssertTrue(result!.contains("\""), "Original quotes should remain")
      XCTAssertTrue(result!.contains("/"), "Original slashes should remain")
      XCTAssertEqual(escaped["plain"] as? String, "Hello")
    }

    func testEscapeJSONDictionary_shouldHandleNestedDictionary() {
      // Given
      let input: [String: Any] = [
        "outer": [
          "attentive_message_title": #"He said "hello"/world"#,
          "other_field": #"Don't escape "this""#
        ]
      ]

      // When
      let escaped = sut.escapeJSONDictionary(input)
      let nested = escaped["outer"] as? [String: Any]
      let escapedTitle = nested?["attentive_message_title"] as? String
      let otherField = nested?["other_field"] as? String

      // Then
      XCTAssertNotNil(escapedTitle)
      // Escaping is no longer done - strings should remain unchanged
      XCTAssertFalse(escapedTitle!.contains("\\\""), "attentive_message_title should NOT be escaped")
      XCTAssertFalse(escapedTitle!.contains("\\/"), "attentive_message_title slashes should NOT be escaped")
      XCTAssertTrue(escapedTitle!.contains("\""), "Original quotes should remain")
      XCTAssertTrue(escapedTitle!.contains("/"), "Original slashes should remain")
      XCTAssertNotNil(otherField)
      XCTAssertFalse(otherField!.contains("\\\""), "other_field should NOT be escaped")
    }

    func testEscapeJSONArray_shouldOnlyEscapeSpecificFields() {
      // Given
      let input: [Any] = [
        "Hello \"friend\"/world",  // Direct strings should NOT be escaped
        ["attentive_message_body": #"A "quote"/slash"#, "other": #"Keep "this""#],
        ["attentive_message_title": #"Title with "quotes""#]
      ]

      // When
      let escaped = sut.escapeJSONArray(input)

      // Then
      // Direct strings in array should NOT be escaped
      let first = escaped.first as? String
      XCTAssertNotNil(first)
      XCTAssertFalse(first!.contains("\\\""), "Direct strings in arrays should NOT be escaped")
      XCTAssertFalse(first!.contains("\\/"), "Direct strings in arrays should NOT be escaped")

      // Escaping is no longer done - attentive_message_body should remain unchanged
      if let nestedDict = escaped[1] as? [String: Any] {
        let messageBody = nestedDict["attentive_message_body"] as? String
        let other = nestedDict["other"] as? String
        XCTAssertNotNil(messageBody)
        XCTAssertFalse(messageBody!.contains("\\\""), "attentive_message_body should NOT be escaped")
        XCTAssertFalse(messageBody!.contains("\\/"), "attentive_message_body slashes should NOT be escaped")
        XCTAssertTrue(messageBody!.contains("\""), "Original quotes should remain")
        XCTAssertTrue(messageBody!.contains("/"), "Original slashes should remain")
        XCTAssertNotNil(other)
        XCTAssertFalse(other!.contains("\\\""), "other field should NOT be escaped")
      } else {
        XCTFail("Expected dictionary at index 1")
      }

      // Escaping is no longer done - attentive_message_title should remain unchanged
      if let titleDict = escaped[2] as? [String: Any],
         let messageTitle = titleDict["attentive_message_title"] as? String {
        XCTAssertFalse(messageTitle.contains("\\\""), "attentive_message_title should NOT be escaped")
        XCTAssertTrue(messageTitle.contains("\""), "Original quotes should remain")
      } else {
        XCTFail("Expected dictionary with attentive_message_title at index 2")
      }
    }

    func testEscapeJSONDictionary_shouldEscapeBothTitleAndBody() {
      // Given
      let input: [String: Any] = [
        "attentive_message_title": #"Title with "quotes" and /slashes"#,
        "attentive_message_body": #"Body with "quotes" and /slashes"#,
        "random_field": #"This has "quotes" but should not be escaped"#
      ]

      // When
      let escaped = sut.escapeJSONDictionary(input)

      // Then
      let title = escaped["attentive_message_title"] as? String
      let body = escaped["attentive_message_body"] as? String
      let random = escaped["random_field"] as? String

      XCTAssertNotNil(title)
      // Escaping is no longer done - strings should remain unchanged
      XCTAssertFalse(title!.contains("\\\""), "attentive_message_title quotes should NOT be escaped")
      XCTAssertFalse(title!.contains("\\/"), "attentive_message_title slashes should NOT be escaped")
      XCTAssertTrue(title!.contains("\""), "Original quotes should remain")
      XCTAssertTrue(title!.contains("/"), "Original slashes should remain")

      XCTAssertNotNil(body)
      XCTAssertFalse(body!.contains("\\\""), "attentive_message_body quotes should NOT be escaped")
      XCTAssertFalse(body!.contains("\\/"), "attentive_message_body slashes should NOT be escaped")
      XCTAssertTrue(body!.contains("\""), "Original quotes should remain")
      XCTAssertTrue(body!.contains("/"), "Original slashes should remain")

      XCTAssertNotNil(random)
      XCTAssertFalse(random!.contains("\\\""), "random_field should NOT be escaped")
    }

    func testEscapeJSONDictionary_shouldHandleDeeplyNestedStructures() {
      // Given
      let input: [String: Any] = [
        "level1": [
          "level2": [
            "attentive_message_body": #"Deep "nested" /value"#,
            "other": #"Don't escape "this""#
          ]
        ]
      ]

      // When
      let escaped = sut.escapeJSONDictionary(input)

      // Then
      if let level1 = escaped["level1"] as? [String: Any],
         let level2 = level1["level2"] as? [String: Any] {
        let messageBody = level2["attentive_message_body"] as? String
        let other = level2["other"] as? String

        XCTAssertNotNil(messageBody)
        // Escaping is no longer done - strings should remain unchanged
        XCTAssertFalse(messageBody!.contains("\\\""), "Deeply nested attentive_message_body should NOT be escaped")
        XCTAssertFalse(messageBody!.contains("\\/"), "Deeply nested attentive_message_body slashes should NOT be escaped")
        XCTAssertTrue(messageBody!.contains("\""), "Original quotes should remain")
        XCTAssertTrue(messageBody!.contains("/"), "Original slashes should remain")

        XCTAssertNotNil(other)
        XCTAssertFalse(other!.contains("\\\""), "Other fields should NOT be escaped even when deeply nested")
      } else {
        XCTFail("Expected nested dictionary structure")
      }
    }

    func testEscapeJSONDictionary_shouldHandleEmptyStringsAndSpecialCases() {
      // Given
      let input: [String: Any] = [
        "attentive_message_title": "",
        "attentive_message_body": "No special chars",
        "other": ""
      ]

      // When
      let escaped = sut.escapeJSONDictionary(input)

      // Then
      XCTAssertEqual(escaped["attentive_message_title"] as? String, "", "Empty string should remain empty")
      XCTAssertEqual(escaped["attentive_message_body"] as? String, "No special chars", "String with no special chars should be unchanged")
      XCTAssertEqual(escaped["other"] as? String, "", "Empty string in non-targeted field should remain empty")
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

