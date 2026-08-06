// swift-tools-version: 5.10

import PackageDescription

let package = Package(
    name: "CodexCurrent",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "CodexCurrent", targets: ["CodexCurrent"])
    ],
    targets: [
        .executableTarget(name: "CodexCurrent")
    ]
)
