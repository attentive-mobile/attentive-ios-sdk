//
//  ATTNPersistentStorageMock.swift
//  attentive-ios-sdk Tests
//

import Foundation
@testable import ATTNSDKFramework

final class ATTNPersistentStorageMock: ATTNPersistentStorageProtocol {
    private let lock = NSLock()
    private var storage: [String: AnyObject] = [:]

    func save(_ value: AnyObject, forKey key: String) {
        lock.withLock { storage[key] = value }
    }

    func readString(forKey key: String) -> String? {
        lock.withLock { storage[key] as? String }
    }

    func delete(forKey key: String) {
        lock.withLock { _ = storage.removeValue(forKey: key) }
    }
}
