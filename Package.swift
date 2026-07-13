// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "CodexMeter",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(name: "CodexMeterCore", targets: ["CodexMeterCore"]),
        .executable(name: "CodexMeter", targets: ["CodexMeter"]),
        .executable(name: "CodexMeterTests", targets: ["CodexMeterTests"])
    ],
    targets: [
        .target(name: "CodexMeterCore"),
        .executableTarget(
            name: "CodexMeter",
            dependencies: ["CodexMeterCore"],
            path: "Sources/CodexMeterApp"
        ),
        .executableTarget(
            name: "CodexMeterTests",
            dependencies: ["CodexMeterCore"],
            path: "Tests/CodexMeterTests"
        )
    ],
    swiftLanguageVersions: [.v5]
)
