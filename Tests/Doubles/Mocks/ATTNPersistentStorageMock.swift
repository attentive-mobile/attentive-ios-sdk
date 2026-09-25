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

    /// Every key currently stored, so tests can assert on what is actually at rest.
    var storedKeys: Set<String> {
        lock.withLock { Set(storage.keys) }
    }

    /// True when any stored string value contains `needle` — used to prove plaintext
    /// contact data never reaches disk.
    func containsStringValue(containing needle: String) -> Bool {
        lock.withLock { storage.values.contains { ($0 as? String)?.contains(needle) == true } }
    }
}
