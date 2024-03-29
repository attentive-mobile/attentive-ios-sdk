// swift-tools-version:5.3
import PackageDescription

let package = Package(
    name: "ExampleSwift",
    platforms: [
       .iOS(.v12)
    ],
    products: [
        .library(
            name: "ExampleSwift",
            targets: ["ExampleSwift"]),
    ],
    dependencies: [
        .package(url: "https://github.com/attentive-mobile/attentive-ios-sdk", .branch("main"))
    ],
    targets: [
        .target(
            name: "ExampleSwift",
            dependencies: [
                .product(name: "ATTNSDKFramework", package: "attentive-ios-sdk")],
            path: "ExampleSwift" // Ensure this path exists and is correct
        ),
    ]
)
