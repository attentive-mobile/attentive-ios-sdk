//
//  ATTNAPISpy.swift
//  attentive-ios-sdk-framework
//

import Foundation
@testable import ATTNSDKFramework
import UserNotifications

final class ATTNAPISpy: ATTNAPIProtocol {

  // MARK: - Call tracking
  private(set) var sendUserIdentityWasCalled = false
  private(set) var sendUserIdentityCallbackWasCalled = false
  private(set) var sendEventWasCalled = false
  private(set) var sendEventCallbackWasCalled = false
  private(set) var sendNewEventWasCalled = false
  private(set) var updateDomainWasCalled = false
  private(set) var domainWasSet = false
  private(set) var cachedGeoAdjustedDomainWasSet = false
  private(set) var sendPushTokenWasCalled = false
  private(set) var sendAppEventsWasCalled = false
  private(set) var sendOptInWasCalled = false
  private(set) var sendOptOutWasCalled = false
  private(set) var updateUserWasCalled = false

  // MARK: - Last-params (optional, handy for assertions)
  private(set) var lastPushToken: String?
  private(set) var lastAuthorizationStatus: UNAuthorizationStatus?
  private(set) var lastOptInEmail: String?
  private(set) var lastOptInPhone: String?
  private(set) var lastOptOutEmail: String?
  private(set) var lastOptOutPhone: String?
  private(set) var lastUpdateUserEmail: String?
  private(set) var lastUpdateUserPhone: String?

  // MARK: - ATTNAPIProtocol state
  var domain: String {
    didSet { domainWasSet = true }
  }

  var cachedGeoAdjustedDomain: String? {
    didSet { cachedGeoAdjustedDomainWasSet = true }
  }

  // MARK: - Init
  init(domain: String) {
    self.domain = domain
  }

  // MARK: - Identity & Events
  func send(userIdentity: ATTNUserIdentity) {
    sendUserIdentityWasCalled = true
  }

  func send(userIdentity: ATTNUserIdentity, callback: ATTNAPICallback?) {
    sendUserIdentityCallbackWasCalled = true
    callback?(nil, nil, nil, nil)
  }

  func send(event: ATTNEvent, userIdentity: ATTNUserIdentity) {
    sendEventWasCalled = true
  }

  func send(event: ATTNEvent, userIdentity: ATTNUserIdentity, callback: ATTNAPICallback?) {
    sendEventCallbackWasCalled = true
    callback?(nil, nil, nil, nil)
  }

  func sendNewEvent<M: Codable>(
    event: ATTNBaseEvent<M>,
    eventRequest: ATTNEventRequest,
    userIdentity: ATTNUserIdentity,
    callback: ATTNAPICallback?
  ) {
    sendNewEventWasCalled = true
    callback?(nil, nil, nil, nil)
  }

  func update(domain newDomain: String) {
    domain = newDomain
    updateDomainWasCalled = true
  }

  // MARK: - Push token & app events
  func sendPushToken(_ pushToken: String,
                     userIdentity: ATTNUserIdentity,
                     authorizationStatus: UNAuthorizationStatus,
                     callback: ATTNAPICallback?) {
    sendPushTokenWasCalled = true
    lastPushToken = pushToken
    lastAuthorizationStatus = authorizationStatus
    callback?(nil, nil, nil, nil)
  }

  func sendAppEvents(
    pushToken: String,
    subscriptionStatus: String,
    transport: String,
    events: [[String: Any]],
    userIdentity: ATTNUserIdentity,
    callback: ATTNAPICallback?
  ) {
    sendAppEventsWasCalled = true
    callback?(nil, nil, nil, nil)
  }

  // MARK: - Marketing subscriptions
  func sendOptInMarketingSubscription(
    pushToken: String,
    email: String?,
    phone: String?,
    userIdentity: ATTNUserIdentity,
    callback: ATTNAPICallback?
  ) {
    sendOptInWasCalled = true
    lastOptInEmail = email
    lastOptInPhone = phone
    callback?(nil, nil, nil, nil)
  }

  func sendOptOutMarketingSubscription(
    pushToken: String,
    email: String?,
    phone: String?,
    userIdentity: ATTNUserIdentity,
    callback: ATTNAPICallback?
  ) {
    sendOptOutWasCalled = true
    lastOptOutEmail = email
    lastOptOutPhone = phone
    callback?(nil, nil, nil, nil)
  }

  // MARK: - Update User
  func updateUser(
    pushToken: String,
    userIdentity: ATTNUserIdentity,
    email: String?,
    phone: String?,
    callback: ATTNAPICallback?
  ) {
    updateUserWasCalled = true
    lastUpdateUserEmail = email
    lastUpdateUserPhone = phone
    callback?(nil, nil, nil, nil)
  }
}
