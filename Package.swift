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
            url: "https://github.com/attentive-mobile/attentive-ios-sdk/releases/download/2.1.0-beta.1/ATTNSDKFramework.xcframework.zip",
            checksum: "e97be85e2a48d507d3fa5be679b09e54f3b07fe6d028f065c4e345bdb7e0a9c6"
        )
    ]
)
