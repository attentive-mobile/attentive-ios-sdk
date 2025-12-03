//
//  ATTNCreativeStateManager.swift
//  attentive-ios-sdk-framework
//
//  Created by Adela Gao on 2/18/25.
//

import Foundation

/// A thread-safe manager for creative state transitions. it uses a concurrent dispatch queue with barrier writes to ensure thread safety
/// Note: This will be refactored to an actor in a future swift concurrency migration
///
enum CreativeState {
    case closed
    case launching
    case open
}

final class ATTNCreativeStateManager {

    static let shared = ATTNCreativeStateManager()
    private var state: CreativeState = .closed
    private let queue = DispatchQueue(label: "com.attentive.creativeStateQueue", attributes: .concurrent)

    func getState() -> CreativeState {
        return queue.sync { state }
    }

    func updateState(_ newState: CreativeState) {
        queue.async(flags: .barrier) {
            self.state = newState
        }
    }

    /// Atomically set state from `expected` to `newState`. Returns true iff it succeeded.
    @discardableResult
    func compareAndSet(from expected: CreativeState, to newState: CreativeState) -> Bool {
        var didSet = false
        queue.sync(flags: .barrier) {
            if self.state == expected {
                self.state = newState
                didSet = true
            }
        }
        return didSet
    }
}
