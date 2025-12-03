//
//  ATTNAppInfo.swift
//  attentive-ios-sdk-framework
//
//  Created by Vladimir - Work on 2024-05-31.
//

import Foundation
import UIKit

protocol ATTNAppInfoProtocol {
    func getAppBuild() -> String
    func getAppVersion() -> String
    func getAppName() -> String
    func getAppId() -> String
    func getDeviceModelName() -> String
    func getDevicePlatform() -> String
    func getDeviceOsVersion() -> String
    func getSdkName() -> String
    func getSdkVersion() -> String
}

extension ATTNAppInfoProtocol {
    func getFormattedAppName() -> String {
        getAppName().replacingOccurrences(of: " ", with: "-")
    }
}

struct ATTNAppInfo: ATTNAppInfoProtocol {
    private enum Constants {
        static var sdkName: String { "attentive-ios-sdk" }
    }

    private enum BundleConstants {
        static var bundleVersion: String { "CFBundleVersion" }
        static var bundleShortVersion: String { "CFBundleShortVersionString" }
        static var bundleName: String { "CFBundleName" }
    }

    private var bundle: Bundle
    private var uiDevice: UIDevice
    private var processInfo: ProcessInfo

    init(
        bundle: Bundle = Bundle.main,
        uiDevice: UIDevice = UIDevice.current,
        processInfo: ProcessInfo = ProcessInfo.processInfo
    ) {
        self.bundle = bundle
        self.uiDevice = uiDevice
        self.processInfo = processInfo
    }

    func getAppBuild() -> String {
        bundle.object(forInfoDictionaryKey: BundleConstants.bundleVersion) as? String ?? ""
    }

    func getAppVersion() -> String {
        bundle.object(forInfoDictionaryKey: BundleConstants.bundleShortVersion) as? String ?? ""
    }

    func getAppName() -> String {
        bundle.object(forInfoDictionaryKey: BundleConstants.bundleName) as? String ?? ""
    }

    func getAppId() -> String {
        bundle.bundleIdentifier ?? ""
    }

    func getDeviceModelName() -> String {
        uiDevice.model
    }

    func getDevicePlatform() -> String {
        uiDevice.systemName
    }

    func getDeviceOsVersion() -> String {
        processInfo.operatingSystemVersionString
    }

    func getSdkName() -> String {
        Constants.sdkName
    }

    func getSdkVersion() -> String {
        ATTNConstants.sdkVersion
    }
}
