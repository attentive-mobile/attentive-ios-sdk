//
//  ATTNAPIProtocol.swift
//  attentive-ios-sdk-framework
//
//  Created by Vladimir - Work on 2024-06-13.
//

import Foundation

protocol ATTNAPIProtocol {
  var domain: String { get set }
  var cachedGeoAdjustedDomain: String? { get set }

  func send(userIdentity: ATTNUserIdentity)
  func send(userIdentity: ATTNUserIdentity, callback: ATTNAPICallback?)
  func send(event: ATTNEvent, userIdentity: ATTNUserIdentity)
  func send(event: ATTNEvent, userIdentity: ATTNUserIdentity, callback: ATTNAPICallback?)
  func update(domain newDomain: String)
  func sendPushToken(_ pushToken: String,
                       for userIdentity: ATTNUserIdentity,
                       callback: ATTNAPICallback?)
}
