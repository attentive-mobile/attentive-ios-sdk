// swift-tools-version:5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "ATTNSDKFramework",
    platforms: [.iOS(.v15)],
    products: [
        .library(name: "ATTNSDKFramework", targets: ["ATTNSDKFramework"])
    ],
    targets: [
        .binaryTarget(
            name: "ATTNSDKFramework",
            url: "https://github.com/attentive-mobile/attentive-ios-sdk/releases/download/2.1.1/ATTNSDKFramework.xcframework.zip",
            checksum: "a7b273ad10f65a75a2a9f16bd8968157fa35f0e1edacfb4829409e542a0624af"
        )
    ]
)
