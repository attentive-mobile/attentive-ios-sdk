// swift-tools-version:5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "ATTNSDKFramework",
    platforms: [.iOS(.v14)],
    products: [
        .library(name: "ATTNSDKFramework", targets: ["ATTNSDKFramework"])
    ],
    targets: [
        .binaryTarget(
            name: "ATTNSDKFramework",
            url: "https://github.com/attentive-mobile/attentive-ios-sdk/releases/download/2.0.15/ATTNSDKFramework.xcframework.zip",
            checksum: "27e8c8913432af004d934105488ef4a80ad0fb612f6b9a2c2e86f8d24398bda8"
        )
    ]
)
