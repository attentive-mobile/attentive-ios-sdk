//
//  ATTNCreativeEmailLead.swift
//  attentive-ios-sdk-framework
//

import Foundation

/// Called each time a user submits their email address in a creative.
///
/// Always called on the main queue.
public typealias ATTNCreativeEmailLeadHandler = (ATTNCreativeEmailLead) -> Void

/// An email address a user submitted in a creative, passed to
/// ``ATTNSDK/creativeEmailLeadHandler``.
///
/// A lead means the user *submitted* an email, not that they are a new subscriber:
/// submitting an address that is already subscribed produces another lead. The SDK
/// passes the address through as the creative sent it, which trims surrounding
/// whitespace but keeps the original letter case.
@objc(ATTNCreativeEmailLead)
public final class ATTNCreativeEmailLead: NSObject {
    /// The submitted email address, or `nil` if the creative's message didn't include one.
    @objc public let email: String?

    /// The full message the creative posted, for fields not modeled here
    /// (for example `creativeId` and `visitorId`).
    @objc public let rawPayload: [String: Any]

    init(email: String?, rawPayload: [String: Any]) {
        self.email = email
        self.rawPayload = rawPayload
        super.init()
    }
}
