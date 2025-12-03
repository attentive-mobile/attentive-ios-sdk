//
//  ATTNUserIdentityExtensionTests.swift
//  attentive-ios-sdk Tests
//
//  Created by Adela Gao on 11/10/25.
//

import XCTest
@testable import ATTNSDKFramework

final class ATTNUserIdentityExtensionTests: XCTestCase {

    // MARK: - encryptedEmail Tests

    func testEncryptedEmail_noEmail_returnsNil() {
        let identity = ATTNUserIdentity(identifiers: [:])

        XCTAssertNil(identity.encryptedEmail)
    }

    func testEncryptedEmail_hasEmail_returnsBase64EncodedEmail() {
        let email = "test@example.com"
        let identity = ATTNUserIdentity(identifiers: [ATTNIdentifierType.email: email])

        XCTAssertNotNil(identity.encryptedEmail)

        // Verify it's base64 encoded
        let expectedBase64 = Data(email.utf8).base64EncodedString()
        XCTAssertEqual(identity.encryptedEmail, expectedBase64)

        // Verify we can decode it back
        guard let base64Data = Data(base64Encoded: identity.encryptedEmail!),
                    let decodedEmail = String(data: base64Data, encoding: .utf8) else {
            XCTFail("Failed to decode base64 email")
            return
        }
        XCTAssertEqual(decodedEmail, email)
    }

    func testEncryptedEmail_hasEmailWithSpecialCharacters_returnsBase64EncodedEmail() {
        let email = "test+special@example.com"
        let identity = ATTNUserIdentity(identifiers: [ATTNIdentifierType.email: email])

        XCTAssertNotNil(identity.encryptedEmail)

        // Verify we can decode it back
        guard let base64Data = Data(base64Encoded: identity.encryptedEmail!),
                    let decodedEmail = String(data: base64Data, encoding: .utf8) else {
            XCTFail("Failed to decode base64 email with special characters")
            return
        }
        XCTAssertEqual(decodedEmail, email)
    }

    func testEncryptedEmail_emailIdentifierIsNotString_returnsNil() {
        let identity = ATTNUserIdentity(identifiers: [ATTNIdentifierType.email: 12345])

        XCTAssertNil(identity.encryptedEmail)
    }

    // MARK: - encryptedPhone Tests

    func testEncryptedPhone_noPhone_returnsNil() {
        let identity = ATTNUserIdentity(identifiers: [:])

        XCTAssertNil(identity.encryptedPhone)
    }

    func testEncryptedPhone_hasPhone_returnsBase64EncodedPhone() {
        let phone = "+14155551234"
        let identity = ATTNUserIdentity(identifiers: [ATTNIdentifierType.phone: phone])

        XCTAssertNotNil(identity.encryptedPhone)

        // Verify it's base64 encoded
        let expectedBase64 = Data(phone.utf8).base64EncodedString()
        XCTAssertEqual(identity.encryptedPhone, expectedBase64)

        // Verify we can decode it back
        guard let base64Data = Data(base64Encoded: identity.encryptedPhone!),
                    let decodedPhone = String(data: base64Data, encoding: .utf8) else {
            XCTFail("Failed to decode base64 phone")
            return
        }
        XCTAssertEqual(decodedPhone, phone)
    }

    func testEncryptedPhone_phoneIdentifierIsNotString_returnsNil() {
        let identity = ATTNUserIdentity(identifiers: [ATTNIdentifierType.phone: 14155551234])

        XCTAssertNil(identity.encryptedPhone)
    }

    // MARK: - Combined Tests

    func testEncryptedEmailAndPhone_bothPresent_returnsBothEncoded() {
        let email = "test@example.com"
        let phone = "+14155551234"
        let identity = ATTNUserIdentity(identifiers: [
            ATTNIdentifierType.email: email,
            ATTNIdentifierType.phone: phone
        ])

        XCTAssertNotNil(identity.encryptedEmail)
        XCTAssertNotNil(identity.encryptedPhone)

        // Verify both can be decoded
        guard let emailData = Data(base64Encoded: identity.encryptedEmail!),
                    let decodedEmail = String(data: emailData, encoding: .utf8) else {
            XCTFail("Failed to decode email")
            return
        }

        guard let phoneData = Data(base64Encoded: identity.encryptedPhone!),
                    let decodedPhone = String(data: phoneData, encoding: .utf8) else {
            XCTFail("Failed to decode phone")
            return
        }

        XCTAssertEqual(decodedEmail, email)
        XCTAssertEqual(decodedPhone, phone)
    }
}
