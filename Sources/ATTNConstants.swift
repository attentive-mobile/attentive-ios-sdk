//
//  ATTNConstants.swift
//  attentive-ios-sdk-framework
//
//  Created by Vladimir - Work on 2024-06-03.
//

import Foundation

struct ATTNConstants {
    private init() { }

    static let sdkVersion = "2.0.17"

    /// Tag-version value that classifies traffic as mobile-app on the backend.
    /// Services like `PurchaseProcessor.shouldIgnorePurchaseEvent` and
    /// `DeviceSpecificCartLinkService.isMobileAppEvent` do an exact string
    /// comparison against this literal, so it must be sent verbatim as `v` on
    /// legacy `/e` requests and `version` on v2 `/mobile` requests — never the
    /// semver `sdkVersion`.
    static let tagVersionMobileApp = "mobile-app"
}
