// swift-tools-version: 5.10

import PackageDescription

let package = Package(
    name: "ScreenFind",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "ScreenFind", targets: ["ScreenFind"])
    ],
    targets: [
        .executableTarget(
            name: "ScreenFind",
            path: "Sources/ScreenFind"
        ),
        .testTarget(
            name: "ScreenFindTests",
            dependencies: ["ScreenFind"],
            path: "Tests/ScreenFindTests"
        )
    ]
)
