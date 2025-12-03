//
//  ATTNAppInfoMock.swift
//  attentive-ios-sdk-framework
//
//  Created by Vladimir - Work on 2024-05-31.
//

import Foundation
@testable import ATTNSDKFramework

class ATTNAppInfoMock: ATTNAppInfoProtocol {
    func getAppBuild() -> String { "appBuildValue" }
    func getAppVersion() -> String { "appVersionValue" }
    func getAppName() -> String { "appName Value" }
    func getAppId() -> String { "appIdValue" }
    func getDeviceModelName() -> String { "deviceModelNameValue" }
    func getDevicePlatform() -> String { "devicePlatformValue" }
    func getDeviceOsVersion() -> String { "deviceOsVersionValue" }
    func getSdkName() -> String { "sdkNameValue" }
    func getSdkVersion() -> String { "sdkVersionValue" }
}
