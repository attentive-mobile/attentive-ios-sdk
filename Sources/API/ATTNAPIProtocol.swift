//
//  ATTNAPIProtocol.swift
//  attentive-ios-sdk-framework
//

import Foundation
import UserNotifications

protocol ATTNAPIProtocol {
  // MARK: - Shared state
  var domain: String { get set }
  var cachedGeoAdjustedDomain: String? { get set }

  // MARK: - Identity & Events
  func send(userIdentity: ATTNUserIdentity)
  func send(userIdentity: ATTNUserIdentity, callback: ATTNAPICallback?)
  func send(event: ATTNEvent, userIdentity: ATTNUserIdentity)
  func send(event: ATTNEvent, userIdentity: ATTNUserIdentity, callback: ATTNAPICallback?)
  func sendNewEvent<M: Codable>(
    event: ATTNBaseEvent<M>,
    eventRequest: ATTNEventRequest,
    userIdentity: ATTNUserIdentity,
    callback: ATTNAPICallback?
  )
  func update(domain newDomain: String)

  // MARK: - Push token & app events
  func sendPushToken(_ pushToken: String,
                     userIdentity: ATTNUserIdentity,
                     authorizationStatus: UNAuthorizationStatus,
                     callback: ATTNAPICallback?)

  func sendAppEvents(
    pushToken: String,
    subscriptionStatus: String,
    transport: String,
    events: [[String: Any]],
    userIdentity: ATTNUserIdentity,
    callback: ATTNAPICallback?
  )

  // MARK: - Marketing subscriptions
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

  // MARK: - Update User
  func updateUser(
    pushToken: String,
    userIdentity: ATTNUserIdentity,
    email: String?,
    phone: String?,
    callback: ATTNAPICallback?
  )
}
