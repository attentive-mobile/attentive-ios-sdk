//
//  ATTNCreativeUrlProviderSpy.swift
//  attentive-ios-sdk-framework
//
//  Created by Vladimir - Work on 2024-06-14.
//

import Foundation
@testable import ATTNSDKFramework

final class ATTNCreativeUrlProviderSpy: ATTNCreativeUrlProviding {
  private(set) var buildCompanyCreativeUrlWasCalled = false
  private(set) var usedDomain: String?
  private(set) var usedCreativeId: String?

  func buildCompanyCreativeUrl(configuration: ATTNSDKFramework.ATTNCreativeUrlConfig) -> String {
    buildCompanyCreativeUrlWasCalled = true
    usedDomain = configuration.domain
    usedCreativeId = configuration.creativeId
    return ""
  }
}
