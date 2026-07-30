//
//  NSLock+Extension.swift
//  attentive-ios-sdk-framework
//

import Foundation

extension NSLock {
    /// Executes `body` while holding the lock, releasing on every exit path.
    /// Mirrors the iOS 16 stdlib `withLock` so error-prone `lock()`/`unlock()`
    /// pairs aren't sprinkled across the SDK on iOS 14/15.
    @discardableResult
    func withLock<T>(_ body: () throws -> T) rethrows -> T {
        lock()
        defer { unlock() }
        return try body()
    }
}
