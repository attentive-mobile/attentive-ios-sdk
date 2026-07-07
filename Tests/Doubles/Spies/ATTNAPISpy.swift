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
    private(set) var sendPushTokenWasCalled = false
    private(set) var sendAppEventsWasCalled = false
    private(set) var sendOptInWasCalled = false
    private(set) var sendOptOutWasCalled = false
    private(set) var updateUserWasCalled = false
    private(set) var updateUserCallCount = 0

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
    private(set) var lastOperationContext: String?
    private(set) var lastUpdateUserPushToken: String?

    func updateUser(
        pushToken: String,
        userIdentity: ATTNUserIdentity,
        email: String?,
        phone: String?,
        operationContext: String,
        callback: ATTNAPICallback?
    ) {
        updateUserWasCalled = true
        updateUserCallCount += 1
        lastUpdateUserPushToken = pushToken
        lastUpdateUserEmail = email
        lastUpdateUserPhone = phone
        lastOperationContext = operationContext
        callback?(nil, nil, nil, nil)
    }

    // MARK: - Inbox
    private(set) var fetchInboxUnreadCountWasCalled = false
    private(set) var fetchInboxUnreadCountCallCount = 0
    private(set) var lastInboxPushToken: String?
    private(set) var lastInboxEmail: String?
    private(set) var lastInboxPhone: String?
    private(set) var lastInboxVisitorId: String?
    var stubbedUnreadCount: Int = 0
    var stubbedInboxError: Error?

    func fetchInboxUnreadCount(
        pushToken: String,
        email: String?,
        phone: String?,
        visitorId: String
    ) async throws -> Int {
        fetchInboxUnreadCountWasCalled = true
        fetchInboxUnreadCountCallCount += 1
        lastInboxPushToken = pushToken
        lastInboxEmail = email
        lastInboxPhone = phone
        lastInboxVisitorId = visitorId
        if let error = stubbedInboxError { throw error }
        return stubbedUnreadCount
    }

    // MARK: - Inbox Messages
    private(set) var fetchInboxMessagesWasCalled = false
    private(set) var fetchInboxMessagesCallCount = 0
    private(set) var lastInboxMessagesPageSize: Int?
    private(set) var lastInboxMessagesPageToken: String?
    private(set) var lastInboxMessagesPushToken: String?
    private(set) var lastInboxMessagesEmail: String?
    private(set) var lastInboxMessagesPhone: String?
    private(set) var lastInboxMessagesVisitorId: String?
    var stubbedInboxMessagesError: Error?
    /// Sequence of responses returned by successive `fetchInboxMessages` calls; the last entry is
    /// reused if more calls arrive than the array has entries.
    var stubbedInboxMessagesResponses: [InboxResponse] = [InboxResponse(messages: [], nextPageToken: nil)]

    func fetchInboxMessages(
        pushToken: String,
        email: String?,
        phone: String?,
        visitorId: String,
        pageSize: Int,
        pageToken: String?
    ) async throws -> InboxResponse {
        fetchInboxMessagesWasCalled = true
        let callIndex = fetchInboxMessagesCallCount
        fetchInboxMessagesCallCount += 1
        lastInboxMessagesPushToken = pushToken
        lastInboxMessagesEmail = email
        lastInboxMessagesPhone = phone
        lastInboxMessagesVisitorId = visitorId
        lastInboxMessagesPageSize = pageSize
        lastInboxMessagesPageToken = pageToken
        if let error = stubbedInboxMessagesError { throw error }
        let index = min(callIndex, stubbedInboxMessagesResponses.count - 1)
        return stubbedInboxMessagesResponses[index]
    }
}
