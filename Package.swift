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
        ),
        .executable(
            name: "LocalWriteMac",
            targets: ["LocalWriteMac"]
        )
    ],
    targets: [
        .target(
            name: "LocalWriteCore",
            path: "Sources/LocalWriteCore"
        ),
        .executableTarget(
            name: "LocalWriteMac",
            dependencies: ["LocalWriteCore"],
            path: "Apps/LocalWrite-macOS"
        ),
        .testTarget(
            name: "LocalWriteCoreTests",
            dependencies: ["LocalWriteCore"],
            path: "Tests/LocalWriteCoreTests"
        )
    ]
)
