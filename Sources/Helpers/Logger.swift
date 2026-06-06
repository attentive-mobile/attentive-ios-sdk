//
//  Logger.swift
//  attentive-ios-sdk-framework
//
//  Created by Vladimir - Work on 2024-06-25.
//

import Foundation
import os

/// Subsystem identifier shared by all SDK loggers.
enum Loggers {
    static let subsystem: String = "com.attentive.attentive-ios-sdk"

    static var network = ATTNLogger(category: "network")
    static var event = ATTNLogger(category: "event")
    static var creative = ATTNLogger(category: "creative")
}

/// A logger that fans out to both `os.Logger` (for Console.app / device logs) and
/// `ATTNLogBuffer` (for the in-app debug overlay). The string-interpolation API
/// matches `os.Logger`'s, so call sites do not need to change.
///
/// Privacy note: every interpolation is forwarded to `os.Logger` as a single
/// `.public` value, since the rendered message is already a `String`. Every existing
/// SDK call site already annotates `, privacy: .public`, so this is a no-op today.
/// Adding `, privacy: .private` to a future call site will not redact the value in
/// Console.app — switch to `os.Logger` directly if that's required.
struct ATTNLogger {
    let category: String
    private let osLogger: Logger

    init(category: String) {
        self.category = category
        self.osLogger = Logger(subsystem: Loggers.subsystem, category: category)
    }

    // Each level forwards `message` as an autoclosure into os.Logger's own lazy
    // string interpolation. When the buffer isn't capturing, os.Logger keeps its
    // native gating: on release builds with `.debug` disabled, the closure isn't
    // evaluated and the call costs nothing — same as calling `os.Logger` directly.
    // When capture is on, we evaluate once and feed both destinations.

    func debug(_ message: @autoclosure @escaping () -> ATTNLogMessage) {
        if ATTNLogBuffer.shared.isCapturing {
            let rendered = message().rendered
            osLogger.debug("\(rendered, privacy: .public)")
            ATTNLogBuffer.shared.append(level: .debug, category: category, message: rendered)
        } else {
            osLogger.debug("\(message().rendered, privacy: .public)")
        }
    }

    func info(_ message: @autoclosure @escaping () -> ATTNLogMessage) {
        if ATTNLogBuffer.shared.isCapturing {
            let rendered = message().rendered
            osLogger.info("\(rendered, privacy: .public)")
            ATTNLogBuffer.shared.append(level: .info, category: category, message: rendered)
        } else {
            osLogger.info("\(message().rendered, privacy: .public)")
        }
    }

    func notice(_ message: @autoclosure @escaping () -> ATTNLogMessage) {
        if ATTNLogBuffer.shared.isCapturing {
            let rendered = message().rendered
            osLogger.notice("\(rendered, privacy: .public)")
            ATTNLogBuffer.shared.append(level: .notice, category: category, message: rendered)
        } else {
            osLogger.notice("\(message().rendered, privacy: .public)")
        }
    }

    func warning(_ message: @autoclosure @escaping () -> ATTNLogMessage) {
        if ATTNLogBuffer.shared.isCapturing {
            let rendered = message().rendered
            osLogger.warning("\(rendered, privacy: .public)")
            ATTNLogBuffer.shared.append(level: .warning, category: category, message: rendered)
        } else {
            osLogger.warning("\(message().rendered, privacy: .public)")
        }
    }

    func error(_ message: @autoclosure @escaping () -> ATTNLogMessage) {
        if ATTNLogBuffer.shared.isCapturing {
            let rendered = message().rendered
            osLogger.error("\(rendered, privacy: .public)")
            ATTNLogBuffer.shared.append(level: .error, category: category, message: rendered)
        } else {
            osLogger.error("\(message().rendered, privacy: .public)")
        }
    }

    func fault(_ message: @autoclosure @escaping () -> ATTNLogMessage) {
        if ATTNLogBuffer.shared.isCapturing {
            let rendered = message().rendered
            osLogger.fault("\(rendered, privacy: .public)")
            ATTNLogBuffer.shared.append(level: .fault, category: category, message: rendered)
        } else {
            osLogger.fault("\(message().rendered, privacy: .public)")
        }
    }
}

/// Mirrors the call-site shape of `os.Logger`'s string interpolation, including the
/// `, privacy:` argument, so existing call sites compile unchanged. The interpolation
/// is rendered eagerly into `rendered` for the in-app log buffer.
struct ATTNLogMessage: ExpressibleByStringInterpolation, ExpressibleByStringLiteral {
    let rendered: String

    init(stringLiteral value: String) {
        self.rendered = value
    }

    init(stringInterpolation: StringInterpolation) {
        self.rendered = stringInterpolation.value
    }

    struct StringInterpolation: StringInterpolationProtocol {
        var value: String

        init(literalCapacity: Int, interpolationCount: Int) {
            value = ""
            value.reserveCapacity(literalCapacity)
        }

        mutating func appendLiteral(_ literal: String) {
            value.append(literal)
        }

        mutating func appendInterpolation<T>(_ argument: @autoclosure () -> T, privacy: OSLogPrivacy = .public) {
            value.append("\(argument())")
        }

        mutating func appendInterpolation(_ argument: @autoclosure () -> String, privacy: OSLogPrivacy = .public) {
            value.append(argument())
        }

        mutating func appendInterpolation(_ argument: @autoclosure () -> any CustomStringConvertible, privacy: OSLogPrivacy = .public) {
            value.append(argument().description)
        }
    }
}
