//
//  ATTNLogBuffer.swift
//  attentive-ios-sdk-framework
//
//  Created by Umair Sharif on 5/12/26.
//

import Foundation

/// In-process ring buffer of recent SDK log lines. Used by the in-app debug overlay
/// in TestFlight/release builds where `OSLogStore` would not surface `.debug` entries.
final class ATTNLogBuffer: @unchecked Sendable {
    static let shared = ATTNLogBuffer()

    private let capacity: Int
    private let evictionSlack: Int
    private let queue = DispatchQueue(label: "com.attentive.sdk.logbuffer")
    private var entries: [ATTNLogEntry] = []
    private var subscribers: [UUID: AsyncStream<ATTNLogEntry>.Continuation] = [:]

    init(capacity: Int = 1000) {
        self.capacity = capacity
        // Trim 25% at a time to amortize the O(n) shift to O(1) per append.
        self.evictionSlack = max(1, capacity / 4)
        entries.reserveCapacity(capacity + evictionSlack)
    }

    func append(level: ATTNLogEntry.Level, category: String, message: String) {
        let entry = ATTNLogEntry(date: Date(), category: category, level: level.rawValue, message: message)
        queue.async {
            self.entries.append(entry)
            if self.entries.count >= self.capacity + self.evictionSlack {
                self.entries.removeFirst(self.evictionSlack)
            }
            for continuation in self.subscribers.values {
                continuation.yield(entry)
            }
        }
    }

    func snapshot(since: Date? = nil) -> [ATTNLogEntry] {
        queue.sync {
            guard let since else { return entries }
            return entries.filter { $0.date >= since }
        }
    }

    /// Async stream of new entries appended after subscription. The caller must
    /// retain the resulting Task; cancelling it removes the subscription.
    func stream() -> AsyncStream<ATTNLogEntry> {
        AsyncStream { continuation in
            let id = UUID()
            queue.async {
                self.subscribers[id] = continuation
            }
            continuation.onTermination = { [weak self] _ in
                self?.queue.async {
                    self?.subscribers.removeValue(forKey: id)
                }
            }
        }
    }
}
