//
//  ATTNLaunchManager.swift
//  attentive-ios-sdk-framework
//
//  Created by Adela Gao on 5/15/25.
//

import Foundation

class ATTNLaunchManager {
  static let shared = ATTNLaunchManager()

  private let queue = DispatchQueue(label: "com.attentive.launchmanager", attributes: .concurrent)
  private var _launchedFromPush = false

  var launchedFromPush: Bool {
    get {
      return queue.sync { _launchedFromPush }
    }
    set {
      queue.async(flags: .barrier) { self._launchedFromPush = newValue }
    }
  }

  func resetPushLaunchFlag() -> Bool {
    return queue.sync {
      if _launchedFromPush {
        _launchedFromPush = false
        return true
      }
      return false
    }
  }
}
