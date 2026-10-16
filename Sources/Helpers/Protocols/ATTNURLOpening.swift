//
//  ATTNURLOpening.swift
//  attentive-ios-sdk-framework
//
//  Created by Umair Sharif on 7/24/26.
//

import UIKit

/// Abstraction over `UIApplication`'s URL opening so deep-link handling can be unit tested.
protocol ATTNURLOpening {
    func open(_ url: URL, options: [UIApplication.OpenExternalURLOptionsKey: Any], completionHandler: ((Bool) -> Void)?)
}

/// Default `ATTNURLOpening` backed by `UIApplication.shared`.
struct ATTNApplicationURLOpener: ATTNURLOpening {
    func open(_ url: URL, options: [UIApplication.OpenExternalURLOptionsKey: Any], completionHandler: ((Bool) -> Void)?) {
        Task { @MainActor in
            UIApplication.shared.open(url, options: options, completionHandler: completionHandler)
        }
    }
}

extension URL {
    /// Schemes the SDK refuses to hand to `UIApplication.open` for server-driven deeplinks —
    /// none of these are legitimate campaign destinations. `javascript:`/`data:` are
    /// script-injection vectors if a message payload is ever misconfigured or attacker-shaped;
    /// the rest trigger system actions or prompts (dialer, SMS/mail composer, FaceTime call,
    /// App Store / mobileconfig install) — an escalation a push tap must never cause without
    /// host consent. Blocked URLs are still broadcast; hosts decide for themselves.
    private static let blockedDeepLinkSchemes: Set<String> = [
        // Scriptable / local-content schemes
        "javascript", "file", "data", "about", "vbscript",
        // Privileged system-action schemes
        "tel", "telprompt", "sms", "mailto", "facetime", "facetime-audio",
        "itms", "itms-apps", "itms-services",
    ]

    /// True when `scheme` is a shape the SDK will hand to `UIApplication.open`: non-empty,
    /// scheme-shaped, and not on the blocked list. The shape check is deliberately looser than
    /// RFC 3986 (which requires a leading letter and forbids `_`): underscores and leading
    /// digits are registrable in Info.plist and the lenient pre-iOS 17 `URL(string:)` parses
    /// them, so schemes like `my_app` or `1password` must not be dropped on iOS 15/16.
    static func attnIsOpenableDeepLinkScheme(_ scheme: String?) -> Bool {
        guard let scheme = scheme?.lowercased(),
              scheme.range(of: "^[a-z0-9][a-z0-9_+.-]*$", options: .regularExpression) != nil else {
            return false
        }
        return !blockedDeepLinkSchemes.contains(scheme)
    }

    /// True when the URL is safe for the SDK to open as a deeplink. `URL(string:)` alone is too
    /// permissive for server-supplied strings: it accepts empty schemes (`"://foo"` parses with
    /// `scheme == ""`), scriptable schemes (`javascript:…`), and privileged system-action
    /// schemes (`tel:…`). `http(s)` and app custom schemes all pass.
    var attnIsOpenableDeepLink: Bool {
        Self.attnIsOpenableDeepLinkScheme(scheme)
    }
}
