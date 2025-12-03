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
            return createNewVisitorId()
        }

        Loggers.event.info("Obtained existing visitor id: \(existingVisitorId)")

        return existingVisitorId
    }

    func createNewVisitorId() -> String {
        let newVisitorId = generateVisitorId()
        persistentStorage.save(newVisitorId as NSObject, forKey: Constants.visitorIdKey)

        Loggers.event.info("Generated new visitor id: \(newVisitorId)")

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
