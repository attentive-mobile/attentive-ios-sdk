//
//  ProcessInfo+Extension.swift
//  attentive-ios-sdk Tests
//
//  Created by Vladimir - Work on 2024-06-17.
//

import Foundation

extension ProcessInfo {
  private static func swizzleEnvironmentImplementation(needsReset: Bool = false) {
    let originalSelector = #selector(getter: ProcessInfo.environment)
    let swizzledSelector = #selector(getter: ProcessInfo.mock_environment)

    guard let originalMethod = class_getInstanceMethod(ProcessInfo.self, originalSelector),
          let swizzledMethod = class_getInstanceMethod(ProcessInfo.self, swizzledSelector) else { return }

    if needsReset {
      method_exchangeImplementations(swizzledMethod, originalMethod)
    } else {
      method_exchangeImplementations(originalMethod, swizzledMethod)
    }
  }

  @objc var mock_environment: [String: String] {
    return ["SKIP_FATIGUE_ON_CREATIVE": "true"]
  }

  static func swizzleEnvironment() {
    self.swizzleEnvironmentImplementation()
  }

  static func restoreOriginalEnvironment() {
    self.swizzleEnvironmentImplementation(needsReset: true)
  }
}
