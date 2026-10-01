import XCTest
@testable import ATTNSDKFramework

final class ATTNErrorTests: XCTestCase {

    // MARK: - LocalizedError

    func testErrorDescriptions() {
        XCTAssertEqual(ATTNError.sdkNotInitialized.localizedDescription, "SDK not initialized")
        XCTAssertEqual(ATTNError.missingContactInfo.localizedDescription, "Provide email and/or phone")
        XCTAssertEqual(ATTNError.badURL.localizedDescription, "Invalid URL")
        XCTAssertEqual(ATTNError.invalidDomain.localizedDescription, "The provided domain is not recognized. Please verify that the domain matches your Attentive settings.")
        XCTAssertEqual(ATTNError.initializationFailed.localizedDescription, "SDK initialization failed")
    }

    // MARK: - CustomNSError

    func testErrorDomain() {
        XCTAssertEqual(ATTNError.errorDomain, "com.attentive.sdk")
    }

    func testErrorCodes() {
        XCTAssertEqual(ATTNError.sdkNotInitialized.errorCode, 1)
        XCTAssertEqual(ATTNError.missingContactInfo.errorCode, 2)
        XCTAssertEqual(ATTNError.badURL.errorCode, 4)
        XCTAssertEqual(ATTNError.invalidDomain.errorCode, 5)
        XCTAssertEqual(ATTNError.initializationFailed.errorCode, 6)
    }

    func testNSErrorBridging() {
        let error: Error = ATTNError.invalidDomain
        let nsError = error as NSError
        XCTAssertEqual(nsError.domain, "com.attentive.sdk")
        XCTAssertEqual(nsError.code, 5)
        XCTAssertEqual(nsError.localizedDescription, "The provided domain is not recognized. Please verify that the domain matches your Attentive settings.")
    }

    // MARK: - ATTNInboxError

    func testInboxErrorDescriptions() {
        XCTAssertEqual(ATTNInboxError.requestFailed(statusCode: 503).localizedDescription, "Inbox request failed with status code 503")
        XCTAssertEqual(ATTNInboxError.responseDecodeFailed.localizedDescription, "Failed to decode inbox response")
    }

    func testInboxErrorDomainAndCodes() {
        XCTAssertEqual(ATTNInboxError.errorDomain, "com.attentive.sdk.inbox")
        XCTAssertEqual(ATTNInboxError.requestFailed(statusCode: 500).errorCode, 1)
        XCTAssertEqual(ATTNInboxError.responseDecodeFailed.errorCode, 2)
    }

    func testInboxErrorNSErrorBridging() {
        let error: Error = ATTNInboxError.requestFailed(statusCode: 404)
        let nsError = error as NSError
        XCTAssertEqual(nsError.domain, "com.attentive.sdk.inbox")
        XCTAssertEqual(nsError.code, 1)
        XCTAssertEqual(nsError.localizedDescription, "Inbox request failed with status code 404")
    }
}
