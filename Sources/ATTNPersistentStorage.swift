//
//  ATTNPersistentStorage.swift
//  attentive-ios-sdk-framework
//
//  Created by Vladimir - Work on 2024-05-29.
//

import Foundation

protocol ATTNPersistentStorageProtocol {
    func save(_ value: AnyObject, forKey key: String)
    func readString(forKey key: String) -> String?
    func delete(forKey key: String)
}

struct ATTNPersistentStorage: ATTNPersistentStorageProtocol {
    private enum Constants {
        static var storagePrefix: String { "com.attentive.iossdk.PERSISTENT_STORAGE" }
    }

    func save(_ value: AnyObject, forKey key: String) {
        UserDefaults.standard.setValue(value, forKey: getPrefixedKey(key))
    }

    func readString(forKey key: String) -> String? {
        UserDefaults.standard.string(forKey: getPrefixedKey(key))
    }

    func delete(forKey key: String) {
        UserDefaults.standard.removeObject(forKey: getPrefixedKey(key))
    }
}

fileprivate extension ATTNPersistentStorage {
    func getPrefixedKey(_ key: String) -> String {
        .init(format: "%@:%@", Constants.storagePrefix, key)
    }
}
