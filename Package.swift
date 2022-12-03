// swift-tools-version: 5.7

import PackageDescription

let package = Package(
    name: "ButtDB",
    platforms: [
        .macOS(.v12),
        .iOS(.v15),
        .watchOS(.v8),
        .tvOS(.v15),
    ],
    products: [
        .library(
            name: "ButtDB",
            targets: ["ButtDB"]),
    ],
    dependencies: [
    ],
    targets: [
        .target(
            name: "ButtDB",
            dependencies: []),
        .testTarget(
            name: "ButtDBTests",
            dependencies: ["ButtDB"]),
    ]
)
