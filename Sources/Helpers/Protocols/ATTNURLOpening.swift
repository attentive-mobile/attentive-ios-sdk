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
    /// none of these are legitimate campaign destinations, and `javascript:`/`data:` are
    /// script-injection vectors if a message payload is ever misconfigured or attacker-shaped.
    private static let blockedDeepLinkSchemes: Set<String> = ["javascript", "file", "data", "about", "vbscript"]

    /// True when the URL is safe for the SDK to open as a deeplink. `URL(string:)` alone is too
    /// permissive for server-supplied strings: it accepts empty schemes (`"://foo"` parses with
    /// `scheme == ""`) and scriptable schemes (`javascript:…`). Requires an RFC 3986-shaped
    /// scheme (letter, then letters/digits/`+`/`-`/`.`) that is not on the blocked list;
    /// `http(s)` and app custom schemes all pass.
    var attnIsOpenableDeepLink: Bool {
        guard let scheme = scheme?.lowercased(),
              scheme.range(of: "^[a-z][a-z0-9+.-]*$", options: .regularExpression) != nil else {
            return false
        }
        return !Self.blockedDeepLinkSchemes.contains(scheme)
    }
}
