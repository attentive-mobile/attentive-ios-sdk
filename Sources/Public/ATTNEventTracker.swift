//
//  ATTNEventTracker.swift
//  attentive-ios-sdk-framework
//
//  Created by Vladimir - Work on 2024-05-30.
//

import Foundation

@objc(ATTNEventTracker)
public final class ATTNEventTracker: NSObject {
  private static var _sharedInstance: ATTNEventTracker?
  private let sdk: ATTNSDK

  @objc(initWithSdk:)
  public init(sdk: ATTNSDK) {
    self.sdk = sdk
  }

  @objc(setupWithSdk:)
  public static func setup(with sdk: ATTNSDK) {
    _sharedInstance = ATTNEventTracker(sdk: sdk)
    Loggers.event.debug("ATTNEventTracker was initialized with SDK")
  }

  @available(swift, deprecated: 0.6, message: "Please use record(event: ATTNEvent) instead.")
  @objc(recordEvent:)
  public func record(_ event: ATTNEvent) {
    sdk.send(event: event)
  }

  public func record(event: ATTNEvent) {
    sdk.send(event: event)
  }

  @objc(recordProductViewEvent:userIdentity:)
  public func record(productViewEvent: ATTNProductViewEvent, userIdentity: ATTNUserIdentity) {
    sdk.sendProductViewEvent(productViewEvent, userIdentitiy: userIdentity)
  }

  @objc
  public static func sharedInstance() -> ATTNEventTracker? {
    assert(_sharedInstance != nil, "ATTNEventTracker must be setup before being used")
    return _sharedInstance
  }
}

// MARK: Internal Helpers
extension ATTNEventTracker {
  static func destroy() {
    _sharedInstance = nil
  }

  func getSdk() -> ATTNSDK {
    sdk
  }
}
