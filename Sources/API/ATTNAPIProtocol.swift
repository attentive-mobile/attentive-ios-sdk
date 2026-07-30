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

    // MARK: - Inbox
    func fetchInboxUnreadCount(
        pushToken: String,
        email: String?,
        phone: String?,
        visitorId: String
    ) async throws -> Int

    /// Fetches a page of inbox messages for the current user.
    /// - Parameters:
    ///   - pageSize: max number of messages to return; server clamps to its own upper bound.
    ///   - pageToken: opaque cursor from a previous response's `next_page_token`; `nil` for the first page.
    func fetchInboxMessages(
        pushToken: String,
        email: String?,
        phone: String?,
        visitorId: String,
        pageSize: Int,
        pageToken: String?
    ) async throws -> InboxResponse

    /// Marks the supplied messages as read on the server. Returns the server-confirmed
    /// per-message read status and the resulting authoritative unread count.
    func markMessagesRead(
        pushToken: String,
        visitorId: String,
        messageIds: [String]
    ) async throws -> UpdateReadStatusResponse

    /// Marks the supplied messages as unread on the server. Returns the server-confirmed
    /// per-message read status and the resulting authoritative unread count.
    func markMessagesUnread(
        pushToken: String,
        visitorId: String,
        messageIds: [String]
    ) async throws -> UpdateReadStatusResponse

    /// Reports a message click to `POST /inbox/events/clicked`. Fire-and-forget from the caller's
    /// perspective — the endpoint returns 204 No Content. Throws on transport failure, non-2xx
    /// status, or bad URL so the caller can decide whether to surface the error.
    func markMessageClicked(
        pushToken: String,
        visitorId: String,
        messageId: String,
        actionURL: String?
    ) async throws

    /// Deletes a single inbox message on the server. Throws on non-2xx responses; callers
    /// are expected to revert any optimistic UI changes on error.
    func deleteInboxMessage(
        pushToken: String,
        visitorId: String,
        messageId: String
    ) async throws
}
