//
//  ATTNVisitorService.swift
//  attentive-ios-sdk-framework
//
//  Created by Vladimir - Work on 2024-05-29.
//

import Foundation
import os

struct ATTNVisitorService {
    private enum Constants {
        static var visitorIdKey: String { "visitorId" }
    }

    private let persistentStorage: ATTNPersistentStorageProtocol
    private let logger: ATTNLogger

    init(
        persistentStorage: ATTNPersistentStorageProtocol = ATTNPersistentStorage(),
        logger: ATTNLogger = Loggers.event
    ) {
        self.persistentStorage = persistentStorage
        self.logger = logger
    }

    func getVisitorId() -> String {
        guard let existingVisitorId = persistentStorage.readString(forKey: Constants.visitorIdKey) else {
            let newVisitorId = createNewVisitorId()
            logNewVisitorId(newVisitorId)
            return newVisitorId
        }

        logger.info("Obtained existing visitor id: \(existingVisitorId, privacy: .public)")

        return existingVisitorId
    }

    /// Deliberately does not log: callers may hold a lock while calling this
    /// (see `ATTNUserIdentity.clearUser()`), and os_log latency is unbounded.
    /// Call `logNewVisitorId(_:)` with the returned id outside any critical
    /// section.
    func createNewVisitorId() -> String {
        let newVisitorId = generateVisitorId()
        persistentStorage.save(newVisitorId as NSObject, forKey: Constants.visitorIdKey)
        return newVisitorId
    }

    /// The logging counterpart to `createNewVisitorId()`, kept separate so the
    /// create step can run inside a lock while the log happens outside it.
    func logNewVisitorId(_ visitorId: String) {
        logger.info("Generated new visitor id: \(visitorId, privacy: .public)")
    }

}

fileprivate extension ATTNVisitorService {
    func generateVisitorId() -> String {
        UUID()
            .uuidString
            .replacingOccurrences(of: "-", with: "")
    }
}
