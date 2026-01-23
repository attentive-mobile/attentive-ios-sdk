//
//  Logger.swift
//  attentive-ios-sdk-framework
//
//  Created by Vladimir - Work on 2024-06-25.
//

import Foundation
import os

enum Loggers {
    private static var subsystem: String { "com.attentive.attentive-ios-sdk" }

    static var network = Logger(subsystem: subsystem, category: "network")
    static var event = Logger(subsystem: subsystem, category: "event")
    static var creative = Logger(subsystem: subsystem, category: "creative")
}
