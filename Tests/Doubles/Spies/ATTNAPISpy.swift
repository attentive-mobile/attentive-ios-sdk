//
//  ATTNAPISpy.swift
//  attentive-ios-sdk-framework
//
//  Created by Vladimir - Work on 2024-06-13.
//

import Foundation
@testable import ATTNSDKFramework

final class ATTNAPISpy: ATTNAPIProtocol {
  private(set) var sendUserIdentityWasCalled = false
  private(set) var sendUserIdentityCallbackWasCalled = false
  private(set) var sendEventWasCalled = false
  private(set) var sendEventCallbackWasCalled = false
  private(set) var updateDomainWasCalled = false
  private(set) var domainWasSetted = false
  private(set) var cachedGeoAdjustedDomainWasSetted = false

  var domain: String {
    didSet {
      domainWasSetted = true
    }
  }

  var cachedGeoAdjustedDomain: String? {
    didSet {
      cachedGeoAdjustedDomainWasSetted = true
    }
  }

  init(domain: String) {
    self.domain = domain
    domainWasSetted = false
  }

  func send(userIdentity: ATTNUserIdentity) {
    sendUserIdentityWasCalled = true
  }
  
  func send(userIdentity: ATTNUserIdentity, callback: ATTNAPICallback?) {
    sendUserIdentityCallbackWasCalled = true
  }
  
  func send(event: any ATTNEvent, userIdentity: ATTNUserIdentity) {
    sendEventWasCalled = true
  }
  
  func send(event: any ATTNEvent, userIdentity: ATTNUserIdentity, callback: ATTNAPICallback?) {
    sendEventCallbackWasCalled = true
  }
  
  func update(domain newDomain: String) {
    domain = newDomain
    updateDomainWasCalled = true
  }
}
