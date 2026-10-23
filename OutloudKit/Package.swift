// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "OutloudKit",
    defaultLocalization: "en",
    platforms: [
        .iOS("27.0"),
        .macOS("27.0"),
    ],
    products: [
        .library(name: "OutloudKit", targets: ["OutloudKit"]),
        .library(name: "OutloudUI", targets: ["OutloudUI"]),
        .executable(name: "outloud", targets: ["OutloudCLI"]),
    ],
    dependencies: [
        // Parakeet v3 (ADR 0006). The text-normalisation trait would add a prebuilt binary
        // Outloud does not use.
        .package(
            url: "https://github.com/FluidInference/FluidAudio.git", exact: "0.17.7", traits: [])
    ],
    targets: [
        .target(
            name: "OutloudKit",
            dependencies: [
                .product(name: "FluidAudio", package: "FluidAudio")
            ],
            resources: [.process("Resources")]),
        .target(
            name: "OutloudUI", dependencies: ["OutloudKit"], resources: [.process("Resources")]),
        .executableTarget(name: "OutloudCLI", dependencies: ["OutloudKit"]),
        .testTarget(name: "OutloudKitTests", dependencies: ["OutloudKit"]),
    ]
)
