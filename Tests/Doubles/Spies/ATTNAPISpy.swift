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
}
