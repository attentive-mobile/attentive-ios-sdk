//
//  ATTNUserAgentBuilderMock.swift
//  attentive-ios-sdk Tests
//
//  Created by Vladimir - Work on 2024-05-31.
//

import Foundation
@testable import ATTNSDKFramework

class ATTNUserAgentBuilderMock: ATTNUserAgentBuilderProtocol {
    func buildUserAgent() -> String { "fakeUserAgent" }
}
