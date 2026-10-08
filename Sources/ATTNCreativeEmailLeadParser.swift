//
//  ATTNCreativeEmailLeadParser.swift
//  attentive-ios-sdk-framework
//

import Foundation

internal enum ATTNCreativeEmailLeadParser {
    static let action = "EMAIL_LEAD"

    /// Parses an `EMAIL_LEAD` creative message. Returns `nil` if `body` isn't an `EMAIL_LEAD` message.
    static func parse(_ body: [String: Any]) -> ATTNCreativeEmailLead? {
        guard body["action"] as? String == action else { return nil }
        let email = (body["email"] as? String).flatMap { $0.isEmpty ? nil : $0 }
        return ATTNCreativeEmailLead(email: email, rawPayload: body)
    }

    /// Whether a script message came from the Attentive creative page. Any frame in the
    /// web view can post to the message handler, so leads from other origins are dropped.
    static func isTrustedOrigin(protocol scheme: String, host: String) -> Bool {
        scheme == ATTNSDKConfiguration.Endpoint.scheme && host == ATTNSDKConfiguration.Endpoint.Creatives.host
    }
}
