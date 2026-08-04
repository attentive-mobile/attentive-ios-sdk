//
//  ATTNVisitorService.swift
//  attentive-ios-sdk-framework
//
//  Created by Vladimir - Work on 2024-05-29.
//

import Foundation

struct ATTNVisitorService {
    private enum Constants {
        static var visitorIdKey: String { "visitorId" }
    }

    private let persistentStorage: ATTNPersistentStorageProtocol

    init(persistentStorage: ATTNPersistentStorageProtocol = ATTNPersistentStorage()) {
        self.persistentStorage = persistentStorage
    }

    func getVisitorId() -> String {
        guard let existingVisitorId = persistentStorage.readString(forKey: Constants.visitorIdKey) else {
            let newVisitorId = createNewVisitorId()
            Loggers.event.info("Generated new visitor id: \(newVisitorId, privacy: .public)")
            return newVisitorId
        }

        Loggers.event.info("Obtained existing visitor id: \(existingVisitorId, privacy: .public)")

        return existingVisitorId
    }

    /// Deliberately does not log: callers may hold a lock while calling this
    /// (see `ATTNUserIdentity.clearUser()`), and os_log latency is unbounded.
    /// Log the returned id at the call site, outside any critical section.
    func createNewVisitorId() -> String {
        let newVisitorId = generateVisitorId()
        persistentStorage.save(newVisitorId as NSObject, forKey: Constants.visitorIdKey)
        return newVisitorId
    }

}

fileprivate extension ATTNVisitorService {
    func generateVisitorId() -> String {
        UUID()
            .uuidString
            .replacingOccurrences(of: "-", with: "")
    }
}
