//
//  ATTNTrackingConsent.swift
//  attentive-ios-sdk-framework
//

import Foundation

/// Explicit pixel-tracking-consent choice supplied by the host app when calling
/// ``ATTNSDK/optInMarketingSubscription(email:phone:trackingConsent:callback:)`` or
/// ``ATTNSDK/optOutMarketingSubscription(email:phone:trackingConsent:callback:)``.
///
/// The SDK does not prompt the user for this value — host apps own the consent-capture UX
/// (checkbox in an account-creation form, preference toggle, etc.) and pass the resulting
/// choice through the SDK.
///
/// **Wire encoding** (JSON body sent to Attentive's subscription endpoints):
///
/// - ``accepted``    → `"trackingConsent": "ACCEPTED"`
/// - ``declined``    → `"trackingConsent": "DECLINED"`
/// - ``unspecified`` → the SDK **omits** the field from the JSON body so the backend
///   applies its own defaulting (e.g. France locale → no pixel tracking).
///
/// This is not ATT-scoped — the SDK's `PrivacyInfo.xcprivacy` still declares
/// `NSPrivacyTracking = false`. Pixel-tracking consent governs email open-tracking under
/// EU ePrivacy regulations (France July 2026, Italy October 2026), separate from Apple's
/// cross-app tracking regime.
///
/// See <https://help.attentive.com/hc/en-us/articles/51464632390804-France-Email-Privacy-Compliance-Update>
/// for the compliance background.
@objc(ATTNTrackingConsent)
public enum ATTNTrackingConsent: Int {
    case unspecified = 0
    case accepted = 1
    case declined = 2

    /// Wire value sent in the JSON body's `trackingConsent` field. Returns `nil` for
    /// ``unspecified`` — the caller **must** omit the field on the wire rather than sending
    /// the literal string "UNSPECIFIED", per the Subscriptions API runbook.
    var wireValue: String? {
        switch self {
        case .unspecified: return nil
        case .accepted: return "ACCEPTED"
        case .declined: return "DECLINED"
        }
    }
}
