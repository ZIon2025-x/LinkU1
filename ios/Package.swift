// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "LinkU",
    platforms: [
        .iOS(.v16)
    ],
    products: [
        .library(
            name: "LinkU",
            targets: ["LinkU"]),
    ],
    dependencies: [
        // 可以在这里添加第三方依赖
    ],
    targets: [
        .target(
            name: "LinkU",
            dependencies: []),
        .testTarget(
            name: "LinkUTests",
            dependencies: ["LinkU"]),
    ]
)

