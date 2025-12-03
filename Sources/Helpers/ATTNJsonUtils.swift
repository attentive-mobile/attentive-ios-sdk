//
//  ATTNJsonUtils.swift
//  attentive-ios-sdk-framework
//
//  Created by Vladimir - Work on 2024-06-03.
//

import Foundation

protocol ATTNJsonUtilsProtocol {
    static func convertObjectToJson(_ object: Any, file: String, function: String) throws -> String?
}

struct ATTNJsonUtils: ATTNJsonUtilsProtocol {
    private init() { }

    static func convertObjectToJson(_ object: Any, file: String = #file, function: String = #function) throws -> String? {
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: object, options: [])
            guard let jsonString = String(data: jsonData, encoding: .utf8) else {
                Loggers.event.error("Could not encode JSON data to a string. Function:\(function), File:\(file)")
                return nil
            }
            return jsonString
        } catch {
            throw error
        }
    }
}
