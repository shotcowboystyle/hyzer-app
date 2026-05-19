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
        .library(name: "HyzerKit", targets: ["HyzerKit"]),
        .library(name: "TestSupport", targets: ["TestSupport"])
    ],
    targets: [
        .target(
            name: "HyzerKit",
            path: "Sources/HyzerKit",
            resources: [.process("Resources")],
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency")
            ]
        ),
        .target(
            name: "TestSupport",
            dependencies: ["HyzerKit"],
            path: "Tests/TestSupport"
        ),
        .testTarget(
            name: "HyzerKitTests",
            dependencies: ["HyzerKit", "TestSupport"],
            path: "Tests/HyzerKitTests"
        )
    ]
)
