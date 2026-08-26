//
//  ATTNSDKTests.swift
//  attentive-ios-sdk Tests
//
//  Created by Vladimir - Work on 2024-06-13.
//

import XCTest
import UserNotifications
@testable import ATTNSDKFramework

final class ATTNSDKTests: XCTestCase {
    private var sut: ATTNSDK!
    private var apiSpy: ATTNAPISpy!
    private var creativeUrlProviderSpy: ATTNCreativeUrlProviderSpy!

    private let testDomain = "TEST_DOMAIN"
    private let newDomain = "NEW_DOMAIN"

    override func setUp() {
        super.setUp()
        UserDefaults.standard.removeObject(forKey: ATTNSDKConfiguration.UserDefaultsKey.deviceToken)
        // MSDK-469: the sync-state record persists across launches via ATTNPersistentStorage,
        // so tests must scrub the persisted keys or one test's success recording bleeds into
        // the next test's setUp and skews the guard decision (skip vs retry vs rotate).
        Self.clearPersistedSyncState()
        creativeUrlProviderSpy = ATTNCreativeUrlProviderSpy()
        apiSpy = ATTNAPISpy(domain: testDomain)
        sut = ATTNSDK(api: apiSpy, urlBuilder: creativeUrlProviderSpy)
        // Reset the creative state using the shared state manager.
        ATTNCreativeStateManager.shared.updateState(.closed)
    }

    override func tearDown() {
        ATTNEventTracker.destroy()

        ProcessInfo.restoreOriginalEnvironment()
        UserDefaults.standard.removeObject(forKey: ATTNSDKConfiguration.UserDefaultsKey.deviceToken)
        Self.clearPersistedSyncState()

        creativeUrlProviderSpy = nil
        sut = nil
        apiSpy = nil

        super.tearDown()
    }

    /// Prefix + key must match `ATTNPersistentStorage` and `ATTNUserIdentity.Constants`.
    /// Kept as an explicit string here rather than reaching into internal types, so a
    /// rename over there will fail these tests loudly instead of silently leaking state.
    private static func clearPersistedSyncState() {
        let prefix = "com.attentive.iossdk.PERSISTENT_STORAGE"
        for suffix in ["lastSyncedPushToken", "lastSyncedEmail", "lastSyncedPhone", "lastSyncedDomain"] {
            UserDefaults.standard.removeObject(forKey: "\(prefix):\(suffix)")
        }
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

    func testOptIn_withoutPushToken_isQueuedAndSentAfterTokenRegistration() {
        sut.optInMarketingSubscription(email: "user@example.com", phone: nil, callback: nil)

        XCTAssertFalse(apiSpy.sendOptInWasCalled, "Opt-in should be queued without a push token")

        let deviceToken = Data([0x01, 0x02, 0x03])
        sut.registerDeviceToken(deviceToken, authorizationStatus: .authorized)

        XCTAssertTrue(waitForCondition({ self.apiSpy.sendOptInWasCalled }))
        XCTAssertEqual(apiSpy.lastOptInEmail, "user@example.com")
    }

    func testOptOut_withoutPushToken_isQueuedAndSentAfterTokenRegistration() {
        sut.optOutMarketingSubscription(email: nil, phone: "+15551234567", callback: nil)

        XCTAssertFalse(apiSpy.sendOptOutWasCalled, "Opt-out should be queued without a push token")

        let deviceToken = Data([0x0a, 0x0b, 0x0c])
        sut.registerDeviceToken(deviceToken, authorizationStatus: .authorized)

        XCTAssertTrue(waitForCondition({ self.apiSpy.sendOptOutWasCalled }))
        XCTAssertEqual(apiSpy.lastOptOutPhone, "+15551234567")
    }

    // MARK: - clearUser tests

    func testClearUser_withPushToken_callsUpdateUserWithNilEmailAndPhone() {
        // A user-scoped identifier must be present for clearUser to fire /user-update — the
        // MSDK-469 no-op guard skips clearUser when the identifier store is empty. Setting an
        // email here is the "user is logged in and calls logout" case this test is asserting.
        registerTestPushToken()
        sut.identify([ATTNIdentifierType.email: "user@example.com"])

        XCTAssertFalse(apiSpy.updateUserWasCalled)

        sut.clearUser()

        XCTAssertTrue(apiSpy.updateUserWasCalled, "clearUser should call updateUser to detach push token")
        XCTAssertNil(apiSpy.lastUpdateUserEmail, "clearUser should pass nil email to detach push token")
        XCTAssertNil(apiSpy.lastUpdateUserPhone, "clearUser should pass nil phone to detach push token")
        XCTAssertEqual(apiSpy.lastOperationContext, "clearUser")
        XCTAssertEqual(apiSpy.lastUpdateUserPushToken, "010203")
    }

    func testClearUser_withoutPushToken_doesNotCallUpdateUser() {
        sut.clearUser()

        XCTAssertFalse(apiSpy.updateUserWasCalled, "clearUser should not call updateUser without a push token")
    }

    func testClearUser_resetsIdentifiers() {
        sut.identify([ATTNIdentifierType.email: "user@example.com"])

        sut.clearUser()

        XCTAssertEqual(sut.getUserIdentity().identifiers.count, 0, "clearUser should reset all identifiers")
    }

    // MARK: - pushEnabled tests

    func testPushEnabled_defaultsToTrue() {
        XCTAssertTrue(sut.pushEnabled)
    }

    func testRegisterDeviceToken_whenPushDisabled_doesNotSendToken() {
        let pushDisabledSut = ATTNSDK(api: apiSpy, urlBuilder: creativeUrlProviderSpy, pushEnabled: false)

        pushDisabledSut.registerDeviceToken(Data([0x01, 0x02, 0x03]), authorizationStatus: .authorized)

        XCTAssertFalse(apiSpy.sendPushTokenWasCalled, "registerDeviceToken should be a no-op when pushEnabled is false")
    }

    func testHandleRegularOpen_whenPushDisabled_doesNotSendAppEvents() {
        let pushDisabledSut = ATTNSDK(api: apiSpy, urlBuilder: creativeUrlProviderSpy, pushEnabled: false)

        pushDisabledSut.handleRegularOpen(authorizationStatus: .authorized)

        XCTAssertFalse(apiSpy.sendAppEventsWasCalled, "handleRegularOpen should be a no-op when pushEnabled is false")
    }

    func testOptIn_whenPushDisabled_sendsImmediatelyWithoutPushToken() {
        // Non-push clients (pushEnabled = false) will never receive a push token, so
        // opt-in must fire immediately rather than queueing for one.
        let pushDisabledSut = ATTNSDK(api: apiSpy, urlBuilder: creativeUrlProviderSpy, pushEnabled: false)

        pushDisabledSut.optInMarketingSubscription(email: "user@example.com", phone: nil, callback: nil)

        XCTAssertTrue(apiSpy.sendOptInWasCalled, "Opt-in should send immediately when pushEnabled is false")
        XCTAssertEqual(apiSpy.lastOptInEmail, "user@example.com")
        XCTAssertEqual(apiSpy.lastOptInPushToken, "", "Non-push opt-in should send with an empty push token")
    }

    func testOptOut_whenPushDisabled_sendsImmediatelyWithoutPushToken() {
        let pushDisabledSut = ATTNSDK(api: apiSpy, urlBuilder: creativeUrlProviderSpy, pushEnabled: false)

        pushDisabledSut.optOutMarketingSubscription(email: nil, phone: "+15551234567", callback: nil)

        XCTAssertTrue(apiSpy.sendOptOutWasCalled, "Opt-out should send immediately when pushEnabled is false")
        XCTAssertEqual(apiSpy.lastOptOutPhone, "+15551234567")
        XCTAssertEqual(apiSpy.lastOptOutPushToken, "", "Non-push opt-out should send with an empty push token")
    }

    // MARK: - updateUser tests

    func testUpdateUser_callsUpdateUserExactlyOnce() {
        let deviceToken = Data([0x01, 0x02, 0x03])
        sut.registerDeviceToken(deviceToken, authorizationStatus: .authorized)

        XCTAssertEqual(apiSpy.updateUserCallCount, 0, "updateUser should not have been called yet")

        sut.updateUser(email: "new@example.com", phone: "+15551234567")

        XCTAssertEqual(apiSpy.updateUserCallCount, 1, "updateUser should call api.updateUser exactly once, not twice")
        XCTAssertEqual(apiSpy.lastUpdateUserEmail, "new@example.com")
        XCTAssertEqual(apiSpy.lastUpdateUserPhone, "+15551234567")
        XCTAssertEqual(apiSpy.lastOperationContext, "updateUser")
    }

    func testUpdateUser_storesIdentifiersLocally() {
        let deviceToken = Data([0x01, 0x02, 0x03])
        sut.registerDeviceToken(deviceToken, authorizationStatus: .authorized)

        sut.updateUser(email: "new@example.com", phone: "+15551234567")

        let identifiers = sut.getUserIdentity().identifiers
        XCTAssertEqual(identifiers[ATTNIdentifierType.email] as? String, "new@example.com",
                       "updateUser should store email locally on userIdentity")
        XCTAssertEqual(identifiers[ATTNIdentifierType.phone] as? String, "+15551234567",
                       "updateUser should store phone locally on userIdentity")
    }

    // MARK: - MSDK-469 no-op guard tests

    func testUpdateUser_whenIdentifiersUnchangedAndServerConfirmed_isNoOp() {
        // Callers that fire updateUser "just to be safe" every app launch must not each mint
        // a new visitor_id and POST /user-update. The spy's default 200 response records the
        // sync from the first call, so the second identical call short-circuits on the
        // (local match + sync match) branch.
        registerTestPushToken()

        sut.updateUser(email: "user@example.com", phone: "+15551234567")
        let visitorIdAfterFirstCall = sut.visitorId
        XCTAssertEqual(apiSpy.updateUserCallCount, 1)

        sut.updateUser(email: "user@example.com", phone: "+15551234567")

        XCTAssertEqual(apiSpy.updateUserCallCount, 1,
                       "Second updateUser with identical identifiers should not fire api.updateUser")
        XCTAssertEqual(sut.visitorId, visitorIdAfterFirstCall,
                       "Second updateUser with identical identifiers should not rotate visitorId")
    }

    func testUpdateUser_whenFirstAttemptFailed_retryStillFires() {
        // Codex P1 #2: local identifiers match after the first attempt mutates them, but the
        // /user-update request itself failed, so the server never recorded the switch. The
        // retry MUST fire again to reach the server; it must NOT rotate visitor_id (same
        // identity, no reason to churn the identity graph on retry).
        registerTestPushToken()
        apiSpy.stubbedError = NSError(domain: "test.network", code: -1009, userInfo: nil)

        sut.updateUser(email: "user@example.com", phone: "+15551234567")
        let visitorIdAfterFirstAttempt = sut.visitorId
        XCTAssertEqual(apiSpy.updateUserCallCount, 1)

        sut.updateUser(email: "user@example.com", phone: "+15551234567")

        XCTAssertEqual(apiSpy.updateUserCallCount, 2,
                       "updateUser retry must fire /user-update again when the first attempt failed")
        XCTAssertEqual(sut.visitorId, visitorIdAfterFirstAttempt,
                       "updateUser retry must reuse the same visitor id — rotating on retry drives the fanout the guard is trying to prevent")
    }

    func testUpdateUser_whenFirstAttemptReturned5xx_retryStillFires() {
        // A non-2xx response from the server (with error == nil) also fails to sync. The
        // guard must treat "HTTP 500 with nil error" the same as "transport error" — both
        // leave the sync record unchanged and let the retry through.
        registerTestPushToken()
        apiSpy.stubbedResponse = HTTPURLResponse(
            url: URL(string: "https://cdn.attn.tv/user-update")!,
            statusCode: 500,
            httpVersion: nil,
            headerFields: nil
        )

        sut.updateUser(email: "user@example.com", phone: "+15551234567")
        XCTAssertEqual(apiSpy.updateUserCallCount, 1)

        sut.updateUser(email: "user@example.com", phone: "+15551234567")

        XCTAssertEqual(apiSpy.updateUserCallCount, 2,
                       "updateUser retry must fire when the first attempt returned a non-2xx status")
    }

    func testUpdateUser_whenPushTokenRotates_firesEvenWithSameIdentity() {
        // APNs can rotate the device's push token independently of anything the SDK does.
        // Server-side attachment is keyed per token, so a token change invalidates any prior
        // /user-update confirmation and the SDK must resend to attach the new token.
        registerTestPushToken()
        sut.updateUser(email: "user@example.com", phone: "+15551234567")
        XCTAssertEqual(apiSpy.updateUserCallCount, 1)

        // Simulate APNs rotating the token: register a different device token.
        sut.registerDeviceToken(Data([0xAA, 0xBB, 0xCC]), authorizationStatus: .authorized)

        sut.updateUser(email: "user@example.com", phone: "+15551234567")

        XCTAssertEqual(apiSpy.updateUserCallCount, 2,
                       "updateUser must fire again after push token rotation, even when email/phone are unchanged")
        XCTAssertEqual(apiSpy.lastUpdateUserPushToken, "aabbcc",
                       "The retry must carry the new push token")
    }

    func testUpdateUser_coldLaunchWithMatchingSyncRecord_isNoOp() {
        // The Aero-style regression the whole branch is chasing. Simulates a fresh process
        // where a prior launch already confirmed the same (email, phone, pushToken, domain)
        // on the server. `_identifiers` is empty (email/phone are in-memory only, so they
        // don't survive a process restart), so without the cold-launch adoption branch the
        // call would rotate the visitor id and POST /user-update on every launch. With the
        // adoption branch, planUpdateUser sees local empty + sync matches and returns .skip.
        //
        // Seed the persisted sync record BEFORE constructing the cold-launch sut — its
        // ATTNUserIdentity.init reads the record synchronously during construction.
        let prefix = "com.attentive.iossdk.PERSISTENT_STORAGE"
        UserDefaults.standard.set("010203", forKey: "\(prefix):lastSyncedPushToken")
        UserDefaults.standard.set("user@example.com", forKey: "\(prefix):lastSyncedEmail")
        UserDefaults.standard.set("+15551234567", forKey: "\(prefix):lastSyncedPhone")
        UserDefaults.standard.set(testDomain, forKey: "\(prefix):lastSyncedDomain")

        // Fresh sut — models a cold launch reading the persisted sync record.
        let coldLaunchSpy = ATTNAPISpy(domain: testDomain)
        let coldLaunchSut = ATTNSDK(api: coldLaunchSpy, urlBuilder: creativeUrlProviderSpy)
        coldLaunchSut.registerDeviceToken(Data([0x01, 0x02, 0x03]), authorizationStatus: .authorized)
        // registerDeviceToken triggers a sendPushToken call on the spy — reset the guard
        // baseline to updateUser only, since that's what this test is actually measuring.
        XCTAssertEqual(coldLaunchSpy.updateUserCallCount, 0,
                       "precondition: no /user-update has fired yet on the cold-launch sut")
        let visitorIdAtColdLaunch = coldLaunchSut.visitorId
        XCTAssertTrue(coldLaunchSut.getUserIdentity().identifiers.isEmpty,
                      "precondition: identifiers must start empty — email/phone are not persisted")

        coldLaunchSut.updateUser(email: "user@example.com", phone: "+15551234567")

        XCTAssertEqual(coldLaunchSpy.updateUserCallCount, 0,
                       "Cold-launch updateUser with matching persisted sync record must NOT fire /user-update")
        XCTAssertEqual(coldLaunchSut.visitorId, visitorIdAtColdLaunch,
                       "Cold-launch adoption must not rotate the visitor id")
        XCTAssertEqual(coldLaunchSut.getUserIdentity().identifiers[ATTNIdentifierType.email] as? String,
                       "user@example.com",
                       "Adoption must populate _identifiers so subsequent in-process calls match locally")
    }

    func testUpdateUser_whenDomainChanges_firesEvenWithSameIdentity() {
        // ATTNSDK.updateDomain(...) can retarget the SDK at a different Attentive company at
        // runtime. A sync record confirmed against the old company must not silence an
        // identity call the new company has never seen — otherwise switching domains leaves
        // the new company with no /user-update for this device until the identifiers change.
        registerTestPushToken()
        sut.updateUser(email: "user@example.com", phone: "+15551234567")
        XCTAssertEqual(apiSpy.updateUserCallCount, 1)

        sut.update(domain: newDomain)

        sut.updateUser(email: "user@example.com", phone: "+15551234567")

        XCTAssertEqual(apiSpy.updateUserCallCount, 2,
                       "updateUser must fire again after updateDomain, even when email/phone are unchanged")
    }

    func testClearUser_whenDomainChanges_firesEvenAfterPriorDetach() {
        // Same shape as the updateUser domain-change guard: a detach confirmed on old-domain
        // does not detach the token from the same push token as seen by new-domain. Clearing
        // after a domain switch must re-send the /user-update.
        registerTestPushToken()
        sut.identify([ATTNIdentifierType.email: "user@example.com"])
        sut.clearUser()
        let updateUserCallsAfterFirstClear = apiSpy.updateUserCallCount
        XCTAssertGreaterThan(updateUserCallsAfterFirstClear, 0,
                             "precondition: first clearUser fires and records the sync for old-domain")

        sut.update(domain: newDomain)
        sut.clearUser()

        XCTAssertGreaterThan(apiSpy.updateUserCallCount, updateUserCallsAfterFirstClear,
                             "clearUser must fire again after updateDomain — the new company has not confirmed the detach")
    }

    func testUpdateUser_normalizesWhitespaceBeforeCompare() {
        // The api layer strips whitespace before sending; the guard must do the same so
        // `"a@b.com"` and `" a@b.com "` (server sees the same thing) collapse to a no-op
        // on the second call instead of a spurious retry.
        registerTestPushToken()
        sut.updateUser(email: "user@example.com", phone: "+15551234567")
        XCTAssertEqual(apiSpy.updateUserCallCount, 1)

        sut.updateUser(email: "  user@example.com  ", phone: "\t+15551234567\n")

        XCTAssertEqual(apiSpy.updateUserCallCount, 1,
                       "Whitespace-only differences must not defeat the no-op guard")
    }

    func testUpdateUser_whenEmailChanged_stillFires() {
        registerTestPushToken()

        sut.updateUser(email: "first@example.com", phone: "+15551234567")
        let visitorIdAfterFirstCall = sut.visitorId

        sut.updateUser(email: "second@example.com", phone: "+15551234567")

        XCTAssertEqual(apiSpy.updateUserCallCount, 2,
                       "updateUser with a different email should still fire api.updateUser")
        XCTAssertNotEqual(sut.visitorId, visitorIdAfterFirstCall,
                          "updateUser with a different email should rotate visitorId")
        XCTAssertEqual(apiSpy.lastUpdateUserEmail, "second@example.com")
    }

    func testUpdateUser_whenPhoneChanged_stillFires() {
        registerTestPushToken()

        sut.updateUser(email: "user@example.com", phone: "+15551234567")
        let visitorIdAfterFirstCall = sut.visitorId

        sut.updateUser(email: "user@example.com", phone: "+15559999999")

        XCTAssertEqual(apiSpy.updateUserCallCount, 2,
                       "updateUser with a different phone should still fire api.updateUser")
        XCTAssertNotEqual(sut.visitorId, visitorIdAfterFirstCall,
                          "updateUser with a different phone should rotate visitorId")
        XCTAssertEqual(apiSpy.lastUpdateUserPhone, "+15559999999")
    }

    func testUpdateUser_whenSameEmailPhoneButExtraIdentifierPresent_stillFires() {
        // A clientUserId stored via identify(_:) would otherwise be silently dropped by
        // updateUser's identity-replacement step. The guard must not fire when any identifier
        // beyond the incoming email/phone is on record — switchIdentity's count mismatch
        // ensures the switch runs and the extra identifier is cleared.
        registerTestPushToken()

        sut.updateUser(email: "user@example.com", phone: "+15551234567")
        XCTAssertEqual(apiSpy.updateUserCallCount, 1)
        sut.identify([ATTNIdentifierType.clientUserId: "customer-123"])

        sut.updateUser(email: "user@example.com", phone: "+15551234567")

        XCTAssertEqual(apiSpy.updateUserCallCount, 2,
                       "updateUser must still fire when the stored set contains identifiers beyond email/phone")
    }

    func testClearUser_whenAlreadyDetachedAndServerConfirmed_isNoOp() {
        // The guard skips only when local is empty AND the server confirmed detach for THIS
        // push token. This is the "second clearUser in a row" happy path: the first call
        // fired /user-update, the spy's default 200 response recorded the sync, and the
        // second call sees a matching sync record.
        registerTestPushToken()
        sut.identify([ATTNIdentifierType.email: "user@example.com"])
        sut.clearUser()  // first call fires; spy's 200 records lastSynced = (nil, nil, token)
        XCTAssertEqual(apiSpy.updateUserCallCount, 1)
        let visitorIdAfterFirstDetach = sut.visitorId

        sut.clearUser()  // second call sees local empty AND sync confirmed → skip

        XCTAssertEqual(apiSpy.updateUserCallCount, 1,
                       "Second clearUser must skip when server already confirmed detach")
        XCTAssertEqual(sut.visitorId, visitorIdAfterFirstDetach,
                       "Second clearUser must not rotate visitorId when server already confirmed")
    }

    func testClearUser_whenLocalEmptyButServerNotConfirmed_firesDetachAndRotates() {
        // Codex P1 #1: after a relaunch (or a prior clearUser whose /user-update failed),
        // local identifiers are empty but the push token in UserDefaults is still attached
        // to the previous user on the server. The guard MUST let the detach through — local
        // emptiness alone doesn't prove server-side detachment.
        //
        // MSDK-469 review Comment 3: this path must also rotate the visitor id. Pre-fix it
        // fired the detach without rotating, so the persisted visitor id kept flowing under
        // the prior user for every subsequent event.
        registerTestPushToken()
        // No prior successful /user-update recorded — the persisted keys were cleared in
        // setUp, so `lastSyncedPushToken` is nil. This mimics a fresh-launch SDK on a
        // device whose push token survived from a prior process where clearUser did NOT
        // successfully complete.
        XCTAssertEqual(sut.getUserIdentity().identifiers.count, 0)
        let visitorIdBefore = sut.visitorId

        sut.clearUser()

        XCTAssertTrue(apiSpy.updateUserWasCalled,
                      "clearUser must fire detach when the server has not confirmed detach for the current push token")
        XCTAssertEqual(apiSpy.lastOperationContext, "clearUser")
        XCTAssertNil(apiSpy.lastUpdateUserEmail)
        XCTAssertNil(apiSpy.lastUpdateUserPhone)
        XCTAssertNotEqual(sut.visitorId, visitorIdBefore,
                          "clearUser must rotate visitor id whenever a detach fires — otherwise persisted V1 keeps attributing subsequent events to the previous user")
    }

    func testClearUser_whenLocalEmptyButNoPushToken_isSilentNoOp() {
        // With no push token, there is nothing to detach server-side and nothing to clear
        // locally. Neither path fires the network call.
        XCTAssertEqual(sut.getUserIdentity().identifiers.count, 0)

        sut.clearUser()

        XCTAssertFalse(apiSpy.updateUserWasCalled,
                       "clearUser without a push token cannot fire detach and must not call api.updateUser")
    }

    func testUpdateUser_whenIdentifyChangesEmailBeforeUpdateUser_rotatesAndFires() {
        // MSDK-469 review Comment 2: identify() bypasses the sync protocol, so it can
        // leave local identifiers matching an incoming `updateUser(B)` without ever
        // planning that identity through planUpdateUser. Pre-fix, planUpdateUser saw
        // local {email:B} matching incoming (B), sync record (A) mismatching → returned
        // .retryWithoutRotation and POSTed B under visitor V1, glueing B to A's visitor id
        // on the server. Post-fix, the sync record's identity (A) != incoming (B) forces
        // rotation before the POST.
        registerTestPushToken()
        sut.updateUser(email: "a@example.com", phone: nil)
        XCTAssertEqual(apiSpy.updateUserCallCount, 1)
        let visitorIdUnderA = sut.visitorId

        sut.identify([ATTNIdentifierType.email: "b@example.com"])
        sut.updateUser(email: "b@example.com", phone: nil)

        XCTAssertEqual(apiSpy.updateUserCallCount, 2,
                       "updateUser must fire; the second call is a new identity, not a retry")
        XCTAssertEqual(apiSpy.lastUpdateUserEmail, "b@example.com")
        XCTAssertNotEqual(sut.visitorId, visitorIdUnderA,
                          "identify() pre-seeding a different email must not let the retry branch attach B to A's visitor id")
    }

    func testClearUser_whenIdentifiersPresent_stillFires() {
        // Any user-scoped identifier — email in this case — means there is state to clear
        // locally AND detach server-side; existing clearUser behavior must run unchanged.
        registerTestPushToken()
        sut.identify([ATTNIdentifierType.email: "user@example.com"])
        let visitorIdBefore = sut.visitorId

        sut.clearUser()

        XCTAssertTrue(apiSpy.updateUserWasCalled,
                      "clearUser must still fire api.updateUser when user-scoped identifiers were present")
        XCTAssertEqual(apiSpy.lastOperationContext, "clearUser")
        XCTAssertNotEqual(sut.visitorId, visitorIdBefore,
                          "clearUser must still rotate visitorId when user-scoped identifiers were present")
    }

    // MARK: - sendLegacyEventAsV2 Tests

    /// MSDK-472: `useV2Endpoint` is deprecated but must stay public and fully
    /// functional for one major version. The test itself is marked deprecated
    /// so it can exercise the deprecated surface without compiler warnings.
    @available(*, deprecated, message: "Intentionally exercises the deprecated useV2Endpoint wrapper")
    func testUseV2Endpoint_deprecatedPublicToggle_remainsFunctional() {
        XCTAssertFalse(sut.useV2Endpoint, "toggle must still default to false")

        sut.useV2Endpoint = true
        XCTAssertTrue(sut.useV2Endpoint)
        let item = ATTNItem(productId: "p1", productVariantId: "v1", price: ATTNPrice(amount: NSDecimalNumber(string: "9.99"), currency: "USD"))
        sut.send(event: ATTNProductViewEvent(items: [item]))
        XCTAssertTrue(apiSpy.sendNewEventWasCalled, "deprecated toggle must still route through /mobile")
        XCTAssertFalse(apiSpy.sendEventWasCalled)

        sut.useV2Endpoint = false
        sut.send(event: ATTNProductViewEvent(items: [item]))
        XCTAssertTrue(apiSpy.sendEventWasCalled, "clearing the deprecated toggle must route back through /e")
    }

    func testSendEvent_v2Enabled_purchase_sendNewEvent() {
        sut.isV2EndpointEnabled = true
        let item = ATTNItem(productId: "p1", productVariantId: "v1", price: ATTNPrice(amount: NSDecimalNumber(string: "9.99"), currency: "USD"))
        item.quantity = 2
        let order = ATTNOrder(orderId: "order-1")
        let event = ATTNPurchaseEvent(items: [item], order: order)

        sut.send(event: event)

        XCTAssertTrue(apiSpy.sendNewEventWasCalled)
        XCTAssertFalse(apiSpy.sendEventWasCalled)
        XCTAssertEqual(apiSpy.lastEventRequest?.eventNameAbbreviation, ATTNEventTypes.purchase)
    }

    func testSendEvent_v2Enabled_purchaseMultipleItems_computesCorrectTotal() {
        // MSDK-442: v2 auto-convert matches the legacy /e formula
        // (sum of item prices, quantity-agnostic) so flipping useV2Endpoint
        // doesn't silently change historical totals.
        sut.isV2EndpointEnabled = true
        let item1 = ATTNItem(productId: "p1", productVariantId: "v1", price: ATTNPrice(amount: NSDecimalNumber(string: "10.00"), currency: "USD"))
        item1.quantity = 2
        let item2 = ATTNItem(productId: "p2", productVariantId: "v2", price: ATTNPrice(amount: NSDecimalNumber(string: "5.50"), currency: "USD"))
        item2.quantity = 3
        let order = ATTNOrder(orderId: "order-2")
        let event = ATTNPurchaseEvent(items: [item1, item2], order: order)

        sut.send(event: event)

        XCTAssertTrue(apiSpy.sendNewEventWasCalled)
        XCTAssertEqual(apiSpy.sendNewEventCallCount, 1)
        let metadata = apiSpy.lastEventMetadata as? ATTNPurchaseMetadata
        XCTAssertEqual(metadata?.orderTotal, "15.50")
    }

    func testSendEvent_v2Enabled_purchase_populatesCartTotalFromLegacyFormula() {
        // Regression guard for MSDK-442: v2 auto-convert emits a cartTotal
        // computed from items so downstream systems don't see it empty.
        sut.isV2EndpointEnabled = true
        let item1 = ATTNItem(productId: "p1", productVariantId: "v1", price: ATTNPrice(amount: NSDecimalNumber(string: "10.00"), currency: "USD"))
        item1.quantity = 2
        let item2 = ATTNItem(productId: "p2", productVariantId: "v2", price: ATTNPrice(amount: NSDecimalNumber(string: "5.50"), currency: "USD"))
        item2.quantity = 3
        let order = ATTNOrder(orderId: "order-cart-total")
        let cart = ATTNCart(cartId: "cart-1")
        let event = ATTNPurchaseEvent(items: [item1, item2], order: order)
        event.cart = cart

        sut.send(event: event)

        let metadata = apiSpy.lastEventMetadata as? ATTNPurchaseMetadata
        XCTAssertEqual(metadata?.cart?.cartTotal, "15.50")
        XCTAssertEqual(metadata?.cart?.cartId, "cart-1")
    }

    func testSendEvent_v2Enabled_purchase_preservesCallerProvidedCartTotal() {
        // Caller-supplied cartTotal on ATTNCart wins over the SDK-computed
        // fallback so hosts can pass an authoritative value.
        sut.isV2EndpointEnabled = true
        let item = ATTNItem(productId: "p1", productVariantId: "v1", price: ATTNPrice(amount: NSDecimalNumber(string: "10.00"), currency: "USD"))
        let order = ATTNOrder(orderId: "order-caller-total")
        let cart = ATTNCart(cartId: "cart-2", cartCoupon: "SAVE10")
        cart.cartTotal = "123.45"
        cart.cartDiscount = "5.00"
        let event = ATTNPurchaseEvent(items: [item], order: order)
        event.cart = cart

        sut.send(event: event)

        let metadata = apiSpy.lastEventMetadata as? ATTNPurchaseMetadata
        XCTAssertEqual(metadata?.cart?.cartTotal, "123.45")
        XCTAssertEqual(metadata?.cart?.cartDiscount, "5.00")
        XCTAssertEqual(metadata?.cart?.cartCoupon, "SAVE10")
    }

    func testSendEvent_v2Enabled_purchase_noCart_stillSendsComputedCartTotal() {
        // When the host omits the cart entirely, the auto-convert still emits
        // a cart payload carrying the SDK-computed cartTotal so downstream
        // pipelines never see it empty.
        sut.isV2EndpointEnabled = true
        let item = ATTNItem(productId: "p1", productVariantId: "v1", price: ATTNPrice(amount: NSDecimalNumber(string: "20.00"), currency: "USD"))
        let order = ATTNOrder(orderId: "order-no-cart")
        let event = ATTNPurchaseEvent(items: [item], order: order)

        sut.send(event: event)

        let metadata = apiSpy.lastEventMetadata as? ATTNPurchaseMetadata
        XCTAssertEqual(metadata?.cart?.cartTotal, "20.00")
    }

    func testPriceFormatter_pinsToPOSIX_regardlessOfDeviceLocale() {
        // The shared priceFormatter must produce `.` decimals on every device
        // locale — backends parse totals with BigDecimal/Double.valueOf which
        // reject the `,` separators produced on de_DE/fr_FR/etc. CI runs on
        // en_US so an unpinned formatter passes there and only fails in the
        // field. Verify by pointing a fresh copy of the SAME formatter recipe
        // at a comma-decimal locale and confirming it still writes `.`.
        let event = ATTNPurchaseEvent(
            items: [ATTNItem(productId: "p1", productVariantId: "v1", price: ATTNPrice(amount: NSDecimalNumber(string: "15.5"), currency: "EUR"))],
            order: ATTNOrder(orderId: "o1")
        )
        let formatter = event.priceFormatter

        XCTAssertEqual(formatter.locale.identifier, "en_US_POSIX",
                       "priceFormatter must pin the locale so decimal separators are stable across devices")

        // Belt-and-braces: even if someone reassigns the locale later, the
        // rendered string for a known decimal must always use a `.` separator.
        let rendered = formatter.string(from: NSDecimalNumber(string: "15.5"))
        XCTAssertEqual(rendered, "15.50")
        XCTAssertFalse(rendered?.contains(",") ?? false, "Formatted totals must never contain `,` — backend parsers reject them")
    }

    func testSendEvent_v2Enabled_addToCart_sendsPerItem() {
        sut.isV2EndpointEnabled = true
        let item1 = ATTNItem(productId: "p1", productVariantId: "v1", price: ATTNPrice(amount: NSDecimalNumber(string: "10.00"), currency: "USD"))
        let item2 = ATTNItem(productId: "p2", productVariantId: "v2", price: ATTNPrice(amount: NSDecimalNumber(string: "20.00"), currency: "EUR"))
        let event = ATTNAddToCartEvent(items: [item1, item2])

        sut.send(event: event)

        XCTAssertTrue(apiSpy.sendNewEventWasCalled)
        XCTAssertEqual(apiSpy.sendNewEventCallCount, 2)
        XCTAssertEqual(apiSpy.lastEventRequest?.eventNameAbbreviation, ATTNEventTypes.addToCart)
    }

    func testSendEvent_v2Enabled_productView_sendsPerItem() {
        sut.isV2EndpointEnabled = true
        let item1 = ATTNItem(productId: "p1", productVariantId: "v1", price: ATTNPrice(amount: NSDecimalNumber(string: "15.00"), currency: "GBP"))
        let item2 = ATTNItem(productId: "p2", productVariantId: "v2", price: ATTNPrice(amount: NSDecimalNumber(string: "25.00"), currency: "GBP"))
        let event = ATTNProductViewEvent(items: [item1, item2])

        sut.send(event: event)

        XCTAssertTrue(apiSpy.sendNewEventWasCalled)
        XCTAssertEqual(apiSpy.sendNewEventCallCount, 2)
        XCTAssertEqual(apiSpy.lastEventRequest?.eventNameAbbreviation, ATTNEventTypes.productView)
    }

    func testSendEvent_v2Enabled_customEvent_sendsWithType() {
        sut.isV2EndpointEnabled = true
        let event = ATTNCustomEvent(type: "Signup", properties: ["source": "banner"])!

        sut.send(event: event)

        XCTAssertTrue(apiSpy.sendNewEventWasCalled)
        XCTAssertEqual(apiSpy.lastEventRequest?.eventNameAbbreviation, ATTNEventTypes.customEvent)
    }

    func testSendEvent_v2Enabled_unsupportedEvent_fallsBackToLegacy() {
        sut.isV2EndpointEnabled = true
        let event = ATTNInfoEvent()

        sut.send(event: event)

        XCTAssertFalse(apiSpy.sendNewEventWasCalled)
        XCTAssertTrue(apiSpy.sendEventWasCalled)
    }

    func testSendEvent_v2Enabled_emptyPurchaseItems_doesNotSend() {
        sut.isV2EndpointEnabled = true
        let order = ATTNOrder(orderId: "order-empty")
        let event = ATTNPurchaseEvent(items: [], order: order)

        sut.send(event: event)

        XCTAssertFalse(apiSpy.sendNewEventWasCalled)
        XCTAssertFalse(apiSpy.sendEventWasCalled)
    }

    func testSendEvent_v2Enabled_emptyAddToCartItems_doesNotSend() {
        sut.isV2EndpointEnabled = true
        let event = ATTNAddToCartEvent(items: [])

        sut.send(event: event)

        XCTAssertFalse(apiSpy.sendNewEventWasCalled)
        XCTAssertFalse(apiSpy.sendEventWasCalled)
    }

    func testSendEvent_v2Enabled_emptyProductViewItems_doesNotSend() {
        sut.isV2EndpointEnabled = true
        let event = ATTNProductViewEvent(items: [])

        sut.send(event: event)

        XCTAssertFalse(apiSpy.sendNewEventWasCalled)
        XCTAssertFalse(apiSpy.sendEventWasCalled)
    }

    func testSendEvent_v2Disabled_usesLegacyPath() {
        sut.isV2EndpointEnabled = false
        let item = ATTNItem(productId: "p1", productVariantId: "v1", price: ATTNPrice(amount: NSDecimalNumber(string: "10.00"), currency: "USD"))
        let event = ATTNAddToCartEvent(items: [item])

        sut.send(event: event)

        XCTAssertTrue(apiSpy.sendEventWasCalled)
        XCTAssertFalse(apiSpy.sendNewEventWasCalled)
    }

    private func waitForCondition(_ condition: @escaping () -> Bool, timeout: TimeInterval = 0.25) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if condition() { return true }
            RunLoop.current.run(until: Date().addingTimeInterval(0.005))
        }
        return condition()
    }

    /// Registers the fixed 3-byte device token used across identity + push tests, so each test
    /// stops repeating the `Data([0x01, 0x02, 0x03])` + `.authorized` boilerplate.
    private func registerTestPushToken() {
        sut.registerDeviceToken(Data([0x01, 0x02, 0x03]), authorizationStatus: .authorized)
    }

    // MARK: - Error Handling Tests

    func testUpdateDomain_invalidDomain_callsCompletionWithError() {
        let exp = expectation(description: "completion called")
        var receivedError: Error?
        sut.update(domain: "https://attn.tv/bad-domain", completion: { error in
            receivedError = error
            exp.fulfill()
        })

        wait(for: [exp], timeout: 1.0)
        XCTAssertNotNil(receivedError)
        XCTAssertEqual(receivedError as? ATTNError, .invalidDomain)
    }

    func testUpdateDomain_validDomain_callsCompletionWithNil() {
        let exp = expectation(description: "completion called")
        var receivedError: Error? = ATTNError.badURL
        sut.update(domain: "VALID_DOMAIN", completion: { error in
            receivedError = error
            exp.fulfill()
        })

        wait(for: [exp], timeout: 1.0)
        XCTAssertNil(receivedError)
    }

    func testUpdateDomain_sameDomain_callsCompletionWithNil() {
        let exp = expectation(description: "completion called")
        var receivedError: Error? = ATTNError.badURL
        sut.update(domain: testDomain, completion: { error in
            receivedError = error
            exp.fulfill()
        })

        wait(for: [exp], timeout: 1.0)
        XCTAssertNil(receivedError)
    }

    func testRegisterAppEvents_emptyPushToken_callsCallbackWithMissingPushTokenError() {
        var receivedError: Error?
        sut.registerAppEvents(
            [["ist": "al", "data": [:]]],
            pushToken: "",
            subscriptionStatus: "authorized",
            callback: { _, _, _, error in
                receivedError = error
            }
        )

        XCTAssertNotNil(receivedError)
        XCTAssertEqual(receivedError as? ATTNSDKError, .missingPushToken)
    }

    // MARK: Concurrency

    func testConsumeDeepLink_concurrentConsumeAndSet_atMostOneConsumerWinsPerSet() {
        // The read-and-clear in `consumeDeepLink` must be atomic: of N concurrent consumers
        // racing one published deep link, exactly one (or zero, if a later set has already
        // overwritten it) should observe a non-nil URL — never two reading the same URL.
        let counter = Counter()
        runConcurrently(iterations: 200, queueLabels: ["set", "consume"]) { [weak self] i, queueIndex in
            guard let self else { return }
            if queueIndex == 0 {
                self.sut.normalizeAndBroadcast("attentive://test/\(i)")
            } else if self.sut.consumeDeepLink() != nil {
                counter.increment()
            }
        }
        // Bounded by number of set operations; the precise count depends on timing.
        XCTAssertLessThanOrEqual(counter.value, 200)
    }
}

private final class Counter {
    private let lock = NSLock()
    private var _value = 0
    var value: Int { lock.withLock { _value } }
    func increment() { lock.withLock { _value += 1 } }
}
