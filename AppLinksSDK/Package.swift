// swift-tools-version: 5.7
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "AppLinksSDK",
    platforms: [
        .iOS(.v14)
    ],
    products: [
        .library(
            name: "AppLinksSDK",
            targets: ["AppLinksSDK"]),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "AppLinksSDK",
            dependencies: []),
        .testTarget(
            name: "AppLinksSDKTests",
            dependencies: ["AppLinksSDK"]),
    ]
)