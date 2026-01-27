//
//  ATTNUserAgentBuilder.swift
//  attentive-ios-sdk-framework
//
//  Created by Vladimir - Work on 2024-05-31.
//

import Foundation

protocol ATTNUserAgentBuilderProtocol {
    func buildUserAgent() -> String
}

class ATTNUserAgentBuilder: ATTNUserAgentBuilderProtocol {
    private var appInfo: ATTNAppInfoProtocol

    init(appInfo: ATTNAppInfoProtocol = ATTNAppInfo()) {
        self.appInfo = appInfo
    }

    func buildUserAgent() -> String {
        // We replace the spaces with dashes for the app name because spaces in a User-Agent represent a new "product", so app names that have spaces are harder to parse if we don't replace spaces with dashes
        let userAgent = String(
            format: "%@/%@.%@ (%@; %@ %@) %@/%@",
            appInfo.getFormattedAppName(),
            appInfo.getAppVersion(),
            appInfo.getAppBuild(),
            appInfo.getDeviceModelName(),
            appInfo.getDevicePlatform(),
            appInfo.getDeviceOsVersion(),
            appInfo.getSdkName(),
            appInfo.getSdkVersion()
        )

        Loggers.event.debug("Created User Agent: \(userAgent, privacy: .public)")

        return userAgent
    }
}
