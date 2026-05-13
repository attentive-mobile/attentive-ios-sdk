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
        XCTAssertEqual(ATTNError.missingPushToken.localizedDescription, "Push token is not available")
        XCTAssertEqual(ATTNError.httpError(statusCode: 404, data: nil).localizedDescription, "HTTP request failed with status code 404")
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
        XCTAssertEqual(ATTNError.missingPushToken.errorCode, 7)
        XCTAssertEqual(ATTNError.httpError(statusCode: 500, data: nil).errorCode, 1500)
    }

    func testHttpErrorCarriesResponseData() {
        let body = "error body".data(using: .utf8)!
        let error = ATTNError.httpError(statusCode: 422, data: body)
        let userInfo = error.errorUserInfo
        XCTAssertEqual(userInfo["responseData"] as? Data, body)
    }

    func testNSErrorBridging() {
        let error: Error = ATTNError.invalidDomain
        let nsError = error as NSError
        XCTAssertEqual(nsError.domain, "com.attentive.sdk")
        XCTAssertEqual(nsError.code, 5)
        XCTAssertEqual(nsError.localizedDescription, "The provided domain is not recognized. Please verify that the domain matches your Attentive settings.")
    }
}
