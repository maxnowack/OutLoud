// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "OutloudKit",
    platforms: [
        .iOS("27.0"),
        .macOS("27.0"),
    ],
    products: [
        .library(name: "OutloudKit", targets: ["OutloudKit"])
    ],
    targets: [
        .target(name: "OutloudKit"),
        .testTarget(name: "OutloudKitTests", dependencies: ["OutloudKit"]),
    ]
)
