//
//  ATTNCreativeUrlProviderSpy.swift
//  attentive-ios-sdk-framework
//
//  Created by Vladimir - Work on 2024-06-14.
//

import Foundation
@testable import ATTNSDKFramework
import XCTest

final class ATTNCreativeUrlProviderSpy: ATTNCreativeUrlProviding {
    private(set) var buildCompanyCreativeUrlWasCalled = false
    private(set) var usedDomain: String?
    private(set) var usedCreativeId: String?

    var buildCompanyCreativeUrlExpectation: XCTestExpectation?

    func buildCompanyCreativeUrl(configuration: ATTNSDKFramework.ATTNCreativeUrlConfig) -> String {
        // Record arguments before the flag/expectation so a test that observes the call
        // (from another thread) never reads stale argument values.
        usedDomain = configuration.domain
        usedCreativeId = configuration.creativeId
        buildCompanyCreativeUrlWasCalled = true
        buildCompanyCreativeUrlExpectation?.fulfill()
        return "https://example.com/creative"
    }
}
