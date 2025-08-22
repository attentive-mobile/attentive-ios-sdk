//
//  ATTNAPIProtocol.swift
//  attentive-ios-sdk-framework
//
//  Created by Vladimir - Work on 2024-06-13.
//

import Foundation
import UserNotifications

protocol ATTNAPIProtocol {
  var domain: String { get set }
  var cachedGeoAdjustedDomain: String? { get set }

  func send(userIdentity: ATTNUserIdentity)
  func send(userIdentity: ATTNUserIdentity, callback: ATTNAPICallback?)
  func send(event: ATTNEvent, userIdentity: ATTNUserIdentity)
  func send(event: ATTNEvent, userIdentity: ATTNUserIdentity, callback: ATTNAPICallback?)
  func update(domain newDomain: String)

  func sendOptInMarketingSubscription(
    pushToken: String,
    email: String?,
    phone: String?,
    userIdentity: ATTNUserIdentity,
    callback: ATTNAPICallback?
  )

  func sendOptOutMarketingSubscription(
    pushToken: String,
    email: String?,
    phone: String?,
    userIdentity: ATTNUserIdentity,
    callback: ATTNAPICallback?
  )

}
