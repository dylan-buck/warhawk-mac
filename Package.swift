// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "WarhawkTool",
    platforms: [.macOS(.v13)],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.3.0"),
    ],
    targets: [
        .target(
            name: "CMachHelpers",
            path: "Sources/CMachHelpers",
            publicHeadersPath: "include"
        ),
        .executableTarget(
            name: "WarhawkTool",
            dependencies: [
                "CMachHelpers",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ],
            path: "Sources/WarhawkTool"
        ),
    ]
)
