// swift-tools-version:5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "ATTNSDKFramework",
    platforms: [.iOS(.v14)],
    products: [
        .library(name: "ATTNSDKFramework", targets: ["ATTNSDKFramework", "ATTNSDKFrameworkObjc"])
    ],
    targets: [
        .target(
            name: "ATTNSDKFramework",
            path: "Sources",
            resources: [ .process("Resources") ]
        ),
        .target(
            name: "ATTNSDKFrameworkObjc",
            dependencies: [],
            path: "Objc",
            publicHeadersPath: "include"
        )
    ]
)
