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
        .library(name: "OutloudLipreading", targets: ["OutloudLipreading"]),
        .executable(name: "outloud", targets: ["OutloudCLI"]),
    ],
    dependencies: [
        // Parakeet v3 (ADR 0006). The text-normalisation trait would add a prebuilt binary
        // Outloud does not use.
        .package(
            url: "https://github.com/FluidInference/FluidAudio.git", exact: "0.17.7", traits: []),
        // Lip reading runs and trains on MLX (ADR 0034); macOS only, so iOS does not link it.
        .package(url: "https://github.com/ml-explore/mlx-swift.git", exact: "0.33.0"),
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
        .target(
            name: "OutloudLipreading",
            dependencies: [
                "OutloudKit",
                .product(name: "MLX", package: "mlx-swift"),
                .product(name: "MLXNN", package: "mlx-swift"),
                .product(name: "MLXOptimizers", package: "mlx-swift"),
            ]),
        .executableTarget(name: "OutloudCLI", dependencies: ["OutloudKit", "OutloudLipreading"]),
        .testTarget(name: "OutloudKitTests", dependencies: ["OutloudKit"]),
        .testTarget(name: "OutloudLipreadingTests", dependencies: ["OutloudLipreading"]),
    ]
)
