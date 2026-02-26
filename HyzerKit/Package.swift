// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "HyzerKit",
    platforms: [
        .iOS(.v18),
        .watchOS(.v11),
        .macOS(.v14)   // Required for `swift test` on macOS host
    ],
    products: [
        .library(name: "HyzerKit", targets: ["HyzerKit"])
    ],
    targets: [
        .target(
            name: "HyzerKit",
            path: "Sources/HyzerKit",
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency")
            ]
        ),
        .testTarget(
            name: "HyzerKitTests",
            dependencies: ["HyzerKit"],
            path: "Tests/HyzerKitTests"
        )
    ]
)
