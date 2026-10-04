// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "LocalWrite",
    platforms: [
        .iOS(.v26),
        .macOS(.v26)
    ],
    products: [
        .library(
            name: "LocalWriteCore",
            targets: ["LocalWriteCore"]
        )
    ],
    targets: [
        .target(
            name: "LocalWriteCore"
        ),
        .testTarget(
            name: "LocalWriteCoreTests",
            dependencies: ["LocalWriteCore"]
        )
    ]
)
