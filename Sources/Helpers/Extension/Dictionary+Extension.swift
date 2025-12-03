//
//  Dictionary+Extension.swift
//  attentive-ios-sdk-framework
//
//  Created by Vladimir - Work on 2024-05-31.
//

import Foundation

extension Dictionary {
    mutating func addEntryIfNotNil(key: Key, value: Value?) {
        if let value = value {
            self[key] = value
        }
    }
}
