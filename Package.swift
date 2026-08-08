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
            url: "https://github.com/attentive-mobile/attentive-ios-sdk/releases/download/2.0.18-beta.1/ATTNSDKFramework.xcframework.zip",
            checksum: "f0e900f7102eba1dbd37f4ea1042f5133d8eccb33ae22252f46076c8cae155c0"
        )
    ]
)
