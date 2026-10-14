//
//  ATTNCreativeEmailLeadParser.swift
//  attentive-ios-sdk-framework
//

import Foundation

internal enum ATTNCreativeEmailLeadParser {
    static let action = "EMAIL_LEAD"

    /// Key the injected listener adds to each forwarded message, holding the `event.origin` of
    /// the frame that sent it. A creative can't set it: the listener overwrites any existing value.
    static let senderOriginKey = "__origin"

    /// Parses an `EMAIL_LEAD` creative message. Returns `nil` if `body` isn't an `EMAIL_LEAD` message.
    static func parse(_ body: [String: Any]) -> ATTNCreativeEmailLead? {
        guard body["action"] as? String == action else { return nil }
        return ATTNCreativeEmailLead(
            email: nonBlankString(body["email"]),
            creativeId: creativeId(from: body["creativeId"]),
            rawPayload: body.filter { $0.key != senderOriginKey }
        )
    }

    /// Whether a script message came from the Attentive creative page. Any frame in the
    /// web view can post to the message handler, so leads from other origins are dropped.
    static func isTrustedOrigin(protocol scheme: String, host: String) -> Bool {
        scheme == ATTNSDKConfiguration.Endpoint.scheme && host == ATTNSDKConfiguration.Endpoint.Creatives.host
    }

    /// Whether the frame that posted the original `window.postMessage` is the Attentive creative
    /// page. The message handler only sees the frame that forwarded it, which is always the
    /// creative page, so a cross-origin child frame could otherwise forge a lead.
    static func isTrustedSenderOrigin(_ origin: String?) -> Bool {
        origin == "\(ATTNSDKConfiguration.Endpoint.scheme)://\(ATTNSDKConfiguration.Endpoint.Creatives.host)"
    }

    private static func nonBlankString(_ value: Any?) -> String? {
        guard let string = value as? String,
              !string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        return string
    }

    /// Creatives send the ID as either a string or a number.
    private static func creativeId(from value: Any?) -> String? {
        guard let value else { return nil }
        // JSON booleans bridge to the same type as numbers, and would cast to Int; they aren't IDs.
        if CFGetTypeID(value as CFTypeRef) == CFBooleanGetTypeID() { return nil }
        if let number = value as? Int { return String(number) }
        return nonBlankString(value)
    }
}
