//
//  ATTNLogEntry.swift
//  attentive-ios-sdk-framework
//
//  Created by Umair Sharif on 5/12/26.
//

import Foundation

/// A snapshot of a single SDK log line, suitable for rendering in a debug console.
@objc(ATTNLogEntry)
public final class ATTNLogEntry: NSObject {
    public enum Level: String, CaseIterable {
        case debug
        case info
        case notice
        case warning
        case error
        case fault
    }

    @objc public let date: Date
    @objc public let category: String
    @objc public let level: String
    @objc public let message: String

    public init(date: Date, category: String, level: String, message: String) {
        self.date = date
        self.category = category
        self.level = level
        self.message = message
    }

    private static let iso8601Formatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    /// Renders `entry` as `<timestamp> [<category>] <LEVEL>: <message>`.
    public func formatted(timestamp: String) -> String {
        "\(timestamp) [\(category)] \(level.uppercased()): \(message)"
    }

    public override var description: String {
        formatted(timestamp: Self.iso8601Formatter.string(from: date))
    }
}
