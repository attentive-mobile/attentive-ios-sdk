//
//  ATTNAPISpy.swift
//  attentive-ios-sdk-framework
//

import Foundation
@testable import ATTNSDKFramework
import UserNotifications

final class ATTNAPISpy: ATTNAPIProtocol {

    // MARK: - Thread safety
    // Tests poll the spy's `*WasCalled` flags (and call counts) from the main thread while
    // the SDK invokes the spy from background queues. All spy state therefore lives in
    // `storage`, and every read and write goes through `synced`, which gives observers a
    // happens-before edge: once a flag reads true, the arguments recorded in the same
    // critical section are guaranteed visible. Each method records its arguments, call
    // count, and flag in ONE critical section, and invokes callbacks OUTSIDE the lock so a
    // re-entrant callback cannot deadlock.
    private let lock = NSLock()
    private var storage = Storage()

    private func synced<T>(_ body: (inout Storage) -> T) -> T {
        lock.lock()
        defer { lock.unlock() }
        return body(&storage)
    }

    private struct Storage {
        // Call tracking
        var sendUserIdentityWasCalled = false
        var sendUserIdentityCallbackWasCalled = false
        var sendEventWasCalled = false
        var sendEventCallbackWasCalled = false
        var sendNewEventWasCalled = false
        var sendNewEventCallCount = 0
        var lastEventRequest: ATTNEventRequest?
        var lastEventMetadata: Any?
        var updateDomainWasCalled = false
        var domainWasSet = false
        var sendPushTokenWasCalled = false
        var sendAppEventsWasCalled = false
        var sendOptInWasCalled = false
        var sendOptOutWasCalled = false
        var updateUserWasCalled = false
        var updateUserCallCount = 0

        // Stubbing
        var stubbedError: Error?
        var stubbedResponse: HTTPURLResponse? = HTTPURLResponse(
            url: URL(string: "https://cdn.attn.tv/user-update")!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )

        // Last-params
        var lastPushToken: String?
        var lastAuthorizationStatus: UNAuthorizationStatus?
        var lastOptInEmail: String?
        var lastOptInPhone: String?
        var lastOptInPushToken: String?
        var lastOptOutEmail: String?
        var lastOptOutPhone: String?
        var lastOptOutPushToken: String?
        var lastUpdateUserEmail: String?
        var lastUpdateUserPhone: String?
        var lastOperationContext: String?
        var lastUpdateUserPushToken: String?

        var domain = ""
    }

    // MARK: - Call tracking
    var sendUserIdentityWasCalled: Bool { synced { $0.sendUserIdentityWasCalled } }
    var sendUserIdentityCallbackWasCalled: Bool { synced { $0.sendUserIdentityCallbackWasCalled } }
    var sendEventWasCalled: Bool { synced { $0.sendEventWasCalled } }
    var sendEventCallbackWasCalled: Bool { synced { $0.sendEventCallbackWasCalled } }
    var sendNewEventWasCalled: Bool { synced { $0.sendNewEventWasCalled } }
    var sendNewEventCallCount: Int { synced { $0.sendNewEventCallCount } }
    var lastEventRequest: ATTNEventRequest? { synced { $0.lastEventRequest } }
    var lastEventMetadata: Any? { synced { $0.lastEventMetadata } }
    var updateDomainWasCalled: Bool { synced { $0.updateDomainWasCalled } }
    var domainWasSet: Bool { synced { $0.domainWasSet } }
    var sendPushTokenWasCalled: Bool { synced { $0.sendPushTokenWasCalled } }
    var sendAppEventsWasCalled: Bool { synced { $0.sendAppEventsWasCalled } }
    var sendOptInWasCalled: Bool { synced { $0.sendOptInWasCalled } }
    var sendOptOutWasCalled: Bool { synced { $0.sendOptOutWasCalled } }
    var updateUserWasCalled: Bool { synced { $0.updateUserWasCalled } }
    var updateUserCallCount: Int { synced { $0.updateUserCallCount } }

    // MARK: - Stubbing
    var stubbedError: Error? {
        get { synced { $0.stubbedError } }
        set { synced { $0.stubbedError = newValue } }
    }
    /// When non-nil, all callback invocations use this response. When nil (default), a
    /// synthetic 200 response is used so that ATTNSDK's `syncRecordingCallback` — which
    /// gates success on `HTTPURLResponse.isSuccessful` — treats the call as a real success.
    /// Set to a non-200 HTTPURLResponse to simulate a failed /user-update.
    var stubbedResponse: HTTPURLResponse? {
        get { synced { $0.stubbedResponse } }
        set { synced { $0.stubbedResponse = newValue } }
    }

    // MARK: - Last-params (optional, handy for assertions)
    var lastPushToken: String? { synced { $0.lastPushToken } }
    var lastAuthorizationStatus: UNAuthorizationStatus? { synced { $0.lastAuthorizationStatus } }
    var lastOptInEmail: String? { synced { $0.lastOptInEmail } }
    var lastOptInPhone: String? { synced { $0.lastOptInPhone } }
    var lastOptInPushToken: String? { synced { $0.lastOptInPushToken } }
    var lastOptOutEmail: String? { synced { $0.lastOptOutEmail } }
    var lastOptOutPhone: String? { synced { $0.lastOptOutPhone } }
    var lastOptOutPushToken: String? { synced { $0.lastOptOutPushToken } }
    var lastUpdateUserEmail: String? { synced { $0.lastUpdateUserEmail } }
    var lastUpdateUserPhone: String? { synced { $0.lastUpdateUserPhone } }
    var lastOperationContext: String? { synced { $0.lastOperationContext } }
    var lastUpdateUserPushToken: String? { synced { $0.lastUpdateUserPushToken } }

    // MARK: - ATTNAPIProtocol state
    var domain: String {
        get { synced { $0.domain } }
        set {
            synced {
                $0.domain = newValue
                $0.domainWasSet = true
            }
        }
    }

    // MARK: - Init
    init(domain: String) {
        // Write the backing field directly so initialization doesn't flip `domainWasSet`,
        // matching the old stored-property behavior where `didSet` doesn't fire in init.
        storage.domain = domain
    }

    // MARK: - Identity & Events
    func send(userIdentity: ATTNUserIdentity) {
        synced { $0.sendUserIdentityWasCalled = true }
    }

    func send(userIdentity: ATTNUserIdentity, callback: ATTNAPICallback?) {
        let error = synced { storage -> Error? in
            storage.sendUserIdentityCallbackWasCalled = true
            return storage.stubbedError
        }
        callback?(nil, nil, nil, error)
    }

    func send(event: ATTNEvent, userIdentity: ATTNUserIdentity) {
        synced { $0.sendEventWasCalled = true }
    }

    func send(event: ATTNEvent, userIdentity: ATTNUserIdentity, callback: ATTNAPICallback?) {
        let error = synced { storage -> Error? in
            storage.sendEventCallbackWasCalled = true
            return storage.stubbedError
        }
        callback?(nil, nil, nil, error)
    }

    func sendNewEvent<M: Codable>(
        event: ATTNBaseEvent<M>,
        eventRequest: ATTNEventRequest,
        userIdentity: ATTNUserIdentity,
        callback: ATTNAPICallback?
    ) {
        let error = synced { storage -> Error? in
            storage.lastEventRequest = eventRequest
            storage.lastEventMetadata = event.eventMetadata
            storage.sendNewEventCallCount += 1
            storage.sendNewEventWasCalled = true
            return storage.stubbedError
        }
        callback?(nil, nil, nil, error)
    }

    func update(domain newDomain: String) {
        synced {
            $0.domain = newDomain
            $0.domainWasSet = true
            $0.updateDomainWasCalled = true
        }
    }

    // MARK: - Push token & app events
    func sendPushToken(_ pushToken: String,
                                         userIdentity: ATTNUserIdentity,
                                         authorizationStatus: UNAuthorizationStatus,
                                         callback: ATTNAPICallback?) {
        let error = synced { storage -> Error? in
            storage.lastPushToken = pushToken
            storage.lastAuthorizationStatus = authorizationStatus
            storage.sendPushTokenWasCalled = true
            return storage.stubbedError
        }
        callback?(nil, nil, nil, error)
    }

    func sendAppEvents(
        pushToken: String,
        subscriptionStatus: String,
        transport: String,
        events: [[String: Any]],
        userIdentity: ATTNUserIdentity,
        callback: ATTNAPICallback?
    ) {
        let error = synced { storage -> Error? in
            storage.sendAppEventsWasCalled = true
            return storage.stubbedError
        }
        callback?(nil, nil, nil, error)
    }

    // MARK: - Marketing subscriptions
    func sendOptInMarketingSubscription(
        pushToken: String,
        email: String?,
        phone: String?,
        userIdentity: ATTNUserIdentity,
        callback: ATTNAPICallback?
    ) {
        let error = synced { storage -> Error? in
            storage.lastOptInEmail = email
            storage.lastOptInPhone = phone
            storage.lastOptInPushToken = pushToken
            storage.sendOptInWasCalled = true
            return storage.stubbedError
        }
        callback?(nil, nil, nil, error)
    }

    func sendOptOutMarketingSubscription(
        pushToken: String,
        email: String?,
        phone: String?,
        userIdentity: ATTNUserIdentity,
        callback: ATTNAPICallback?
    ) {
        let error = synced { storage -> Error? in
            storage.lastOptOutEmail = email
            storage.lastOptOutPhone = phone
            storage.lastOptOutPushToken = pushToken
            storage.sendOptOutWasCalled = true
            return storage.stubbedError
        }
        callback?(nil, nil, nil, error)
    }

    // MARK: - Update User
    func updateUser(
        pushToken: String,
        userIdentity: ATTNUserIdentity,
        email: String?,
        phone: String?,
        operationContext: String,
        callback: ATTNAPICallback?
    ) {
        let (response, error) = synced { storage -> (HTTPURLResponse?, Error?) in
            storage.lastUpdateUserPushToken = pushToken
            storage.lastUpdateUserEmail = email
            storage.lastUpdateUserPhone = phone
            storage.lastOperationContext = operationContext
            storage.updateUserCallCount += 1
            storage.updateUserWasCalled = true
            return (storage.stubbedResponse, storage.stubbedError)
        }
        // Pass `stubbedResponse` so ATTNSDK.syncRecordingCallback can distinguish a real
        // 200 from a 5xx. Tests that need to simulate a failed /user-update set
        // `stubbedResponse` to a non-2xx or `stubbedError` to a non-nil error.
        callback?(nil, nil, response, error)
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
    /// Fires inside the stub *before* it returns, so tests can drive concurrent state (e.g.
    /// reset the identity mid-flight) and observe how the manager handles a slow count fetch.
    var onFetchInboxUnreadCount: (@Sendable () async -> Void)?

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
        if let hook = onFetchInboxUnreadCount { await hook() }
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
    /// Invoked while a `fetchInboxMessages` call is "in flight" (after recording args, before
    /// returning a response). Lets tests interleave a follow-up call to reproduce races.
    var onFetchInboxMessages: (@Sendable (_ pageToken: String?) async -> Void)?

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
        if let hook = onFetchInboxMessages { await hook(pageToken) }
        if let error = stubbedInboxMessagesError { throw error }
        let index = min(callIndex, stubbedInboxMessagesResponses.count - 1)
        return stubbedInboxMessagesResponses[index]
    }

    // MARK: - Mark Messages Read
    private(set) var markMessagesReadWasCalled = false
    private(set) var markMessagesReadCallCount = 0
    private(set) var lastMarkReadPushToken: String?
    private(set) var lastMarkReadVisitorId: String?
    private(set) var lastMarkReadMessageIds: [String]?
    var stubbedMarkReadError: Error?
    var stubbedMarkReadResponse: UpdateReadStatusResponse = UpdateReadStatusResponse(
        messages: [],
        unreadCount: 0
    )
    /// Invoked while the mark-read call is "in flight" (after recording, before returning), letting
    /// a test interleave an identity change/refresh to exercise stale-response handling.
    var onMarkMessagesRead: (@Sendable () async -> Void)?

    func markMessagesRead(
        pushToken: String,
        visitorId: String,
        messageIds: [String]
    ) async throws -> UpdateReadStatusResponse {
        markMessagesReadWasCalled = true
        markMessagesReadCallCount += 1
        lastMarkReadPushToken = pushToken
        lastMarkReadVisitorId = visitorId
        lastMarkReadMessageIds = messageIds
        if let hook = onMarkMessagesRead { await hook() }
        if let error = stubbedMarkReadError { throw error }
        return stubbedMarkReadResponse
    }

    // MARK: - Mark Messages Unread
    private(set) var markMessagesUnreadWasCalled = false
    private(set) var markMessagesUnreadCallCount = 0
    private(set) var lastMarkUnreadPushToken: String?
    private(set) var lastMarkUnreadVisitorId: String?
    private(set) var lastMarkUnreadMessageIds: [String]?
    var stubbedMarkUnreadError: Error?
    var stubbedMarkUnreadResponse: UpdateReadStatusResponse = UpdateReadStatusResponse(
        messages: [],
        unreadCount: 0
    )
    /// Invoked while the mark-unread call is "in flight" (after recording, before returning),
    /// letting a test interleave an identity change/refresh to exercise stale-response handling.
    var onMarkMessagesUnread: (@Sendable () async -> Void)?

    func markMessagesUnread(
        pushToken: String,
        visitorId: String,
        messageIds: [String]
    ) async throws -> UpdateReadStatusResponse {
        markMessagesUnreadWasCalled = true
        markMessagesUnreadCallCount += 1
        lastMarkUnreadPushToken = pushToken
        lastMarkUnreadVisitorId = visitorId
        lastMarkUnreadMessageIds = messageIds
        if let hook = onMarkMessagesUnread { await hook() }
        if let error = stubbedMarkUnreadError { throw error }
        return stubbedMarkUnreadResponse
    }

    // MARK: - Mark Messages Clicked
    private(set) var markMessageClickedWasCalled = false
    private(set) var markMessageClickedCallCount = 0
    private(set) var lastMarkClickedPushToken: String?
    private(set) var lastMarkClickedVisitorId: String?
    private(set) var lastMarkClickedMessageId: String?
    private(set) var lastMarkClickedActionURL: String?
    var stubbedMarkClickedError: Error?

    func markMessageClicked(
        pushToken: String,
        visitorId: String,
        messageId: String,
        actionURL: String?
    ) async throws {
        markMessageClickedWasCalled = true
        markMessageClickedCallCount += 1
        lastMarkClickedPushToken = pushToken
        lastMarkClickedVisitorId = visitorId
        lastMarkClickedMessageId = messageId
        lastMarkClickedActionURL = actionURL
        if let error = stubbedMarkClickedError { throw error }
    }

    // MARK: - Inbox Delete
    private(set) var deleteInboxMessageCallCount = 0
    private(set) var lastDeletePushToken: String?
    private(set) var lastDeleteVisitorId: String?
    private(set) var lastDeleteMessageId: String?
    var stubbedDeleteInboxMessageError: Error?
    /// Invoked while the delete call is "in flight" (after recording args, before returning),
    /// letting a test interleave an identity change / refresh to exercise stale-response handling.
    var onDeleteInboxMessage: (@Sendable () async -> Void)?

    func deleteInboxMessage(
        pushToken: String,
        visitorId: String,
        messageId: String
    ) async throws {
        deleteInboxMessageCallCount += 1
        lastDeletePushToken = pushToken
        lastDeleteVisitorId = visitorId
        lastDeleteMessageId = messageId
        if let hook = onDeleteInboxMessage { await hook() }
        if let error = stubbedDeleteInboxMessageError { throw error }
    }
}
