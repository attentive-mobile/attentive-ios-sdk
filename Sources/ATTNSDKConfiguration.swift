//
//  ATTNSDKConfiguration.swift
//  attentive-ios-sdk-framework
//

import Foundation

/// Single source of truth for network endpoints, timeouts, retry policy, and
/// persistent-storage keys used by the SDK. Any new endpoint, header, or
/// default value should be added here instead of being inlined at the call site.
internal enum ATTNSDKConfiguration {

    // MARK: - Endpoints

    /// Scheme/host/path/port for every SDK endpoint. When adding a new endpoint,
    /// extend this enum rather than building a URL from a string literal.
    enum Endpoint {
        static let scheme = "https"

        /// `events.attentivemobile.com` — legacy event pipeline (`/e`) and new
        /// typed event pipeline (`/mobile`).
        enum Events {
            static let host = "events.attentivemobile.com"
            static let legacyPath = "/e"
            static let newEventPath = "/mobile"
        }

        /// `mobile.attentivemobile.com` — push token, marketing control,
        /// opt-in/opt-out, and user-update endpoints.
        enum Mobile {
            static let host = "mobile.attentivemobile.com"
            static let port = 443
            static let pushTokenPath = "/token"
            static let appEventsPath = "/mtctrl"
            static let optInPath = "/opt-in-subscriptions"
            static let optOutPath = "/opt-out-subscriptions"
            static let userUpdatePath = "/user-update"

            static let appEventsURL: URL? = url(path: appEventsPath)
            static let optInURL: URL? = url(path: optInPath)
            static let optOutURL: URL? = url(path: optOutPath)
            static let userUpdateURL: URL? = url(path: userUpdatePath, includePort: true)

            private static func url(path: String, includePort: Bool = false) -> URL? {
                var components = URLComponents()
                components.scheme = Endpoint.scheme
                components.host = host
                components.path = path
                if includePort { components.port = port }
                return components.url
            }
        }

        /// `creatives.attn.tv` — hosts the creative web experience rendered in
        /// a web view.
        enum Creatives {
            static let host = "creatives.attn.tv"
            static let path = "/mobile-apps/index.html"
        }

        /// A customer domain configured on the SDK is considered invalid when
        /// it contains any of these substrings — the SDK expects the bare
        /// customer domain, not a URL.
        static let invalidDomainSubstrings = ["attn.tv", "/", ":"]
    }

    // MARK: - Timeouts

    /// Default request timeout applied to SDK network requests. Endpoints
    /// should pass this into their `URLRequest.timeoutInterval` rather than
    /// picking an ad-hoc value.
    enum Timeout {
        static let defaultRequest: TimeInterval = 15
    }

    // MARK: - Retry policy

    /// Defaults consumed by `ATTNRetryingNetworkClient`.
    enum Retry {
        static let initialDelay: TimeInterval = 1.0
        static let maxRetries = 5
        static let jitterRange: ClosedRange<Double> = -0.5...0.5
        static let maxCumulativeDelay: TimeInterval = 300.0
    }

    // MARK: - HTTP headers

    enum Headers {
        static let contentType = "Content-Type"
        static let datadogSamplingPriority = "x-datadog-sampling-priority"

        static let applicationJSON = "application/json"
        static let formURLEncoded = "application/x-www-form-urlencoded; charset=utf-8"

        /// Datadog sampling decision — `"1"` tells the collector to keep this
        /// trace; `"0"` would drop it. SDK endpoints always keep.
        static let datadogSamplingPriorityKeep = "1"
    }

    // MARK: - UserDefaults keys

    /// Raw `UserDefaults` keys. Use `ATTNPersistentStorage` for new keys —
    /// these exist because the values are read/written outside that wrapper.
    enum UserDefaultsKey {
        static let deviceToken = "attentiveDeviceToken"
        static let lastAuthStatus = "attentiveLastAuthStatus"
    }
}
