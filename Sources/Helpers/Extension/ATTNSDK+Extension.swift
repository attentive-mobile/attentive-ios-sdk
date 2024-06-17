//
//  ATTNSDK+Extension.swift
//  attentive-ios-sdk-framework
//
//  Created by Vladimir - Work on 2024-06-17.
//

import Foundation

extension ATTNSDK {
  func send(event: ATTNEvent) {
    api.send(event: event, userIdentity: userIdentity)
  }

  func initializeSkipFatigueOnCreatives() {
    if let skipFatigueValue = ProcessInfo.processInfo.environment[ATTNConstants.skipFatigueEnvKey] {
      self.skipFatigueOnCreative = skipFatigueValue.booleanValue
    } else {
      self.skipFatigueOnCreative = false
    }
  }
}
