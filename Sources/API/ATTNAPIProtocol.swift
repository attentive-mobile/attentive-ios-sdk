//
//  ATTNAPIProtocol.swift
//  attentive-ios-sdk-framework
//

import Foundation
import UserNotifications

protocol ATTNAPIProtocol {
    // MARK: - Shared state
    var domain: String { get set }

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
    //
    // Shared endpoint for both `clearUser()` and `updateUser(email:phone:)`.
    //
    // - When called from clearUser:  email=nil, phone=nil, operationContext="clearUser"
    //   → Tells the server to detach the push token from the current user (logout flow).
    //
    // - When called from updateUser: email/phone provided, operationContext="updateUser"
    //   → Tells the server to re-identify the device under a new user.
    //
    // `operationContext` is used exclusively for logging — it has no effect on the API payload.
    func updateUser(
        pushToken: String,
        userIdentity: ATTNUserIdentity,
        email: String?,
        phone: String?,
        operationContext: String,
        callback: ATTNAPICallback?
    )
}
