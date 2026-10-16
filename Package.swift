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
            url: "https://github.com/attentive-mobile/attentive-ios-sdk/releases/download/2.2.0/ATTNSDKFramework.xcframework.zip",
            checksum: "5ff6f11ae2ca65af5840786b0c27e70adf5cbc19ace37ad8484fbc3bb99f68c1"
        )
    ]
)
