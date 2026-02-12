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
            url: "https://github.com/attentive-mobile/attentive-ios-sdk/releases/download/2.0.11/ATTNSDKFramework.xcframework.zip",
            checksum: "9752d68b5a361a3c974e89c3c88dc79dd38d1f5d8af2591918040ae11b89700e"
        )
    ]
)
