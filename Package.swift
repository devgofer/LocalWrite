// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "LocalWrite",
    platforms: [
        .iOS(.v26),
        .macOS(.v26)
    ],
    products: [
        .library(name: "LocalWriteKeyboardBridge", targets: ["LocalWriteKeyboardBridge"]),
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
        .target(name: "LocalWriteKeyboardBridge"),
        .testTarget(name: "LocalWriteKeyboardBridgeTests", dependencies: ["LocalWriteKeyboardBridge"]),
        .target(
            name: "LocalWriteCore",
            path: "Sources/LocalWriteCore"
        ),
        .executableTarget(
            name: "LocalWriteMac",
            dependencies: ["LocalWriteCore"],
            path: "Apps/LocalWrite-macOS",
            exclude: ["Info.plist", "LocalWrite.entitlements"]
        ),
        .testTarget(
            name: "LocalWriteMacTests",
            dependencies: ["LocalWriteMac"],
            path: "Tests/LocalWriteMacTests"
        ),
        .testTarget(
            name: "LocalWriteCoreTests",
            dependencies: ["LocalWriteCore"],
            path: "Tests/LocalWriteCoreTests"
        )
    ]
)
