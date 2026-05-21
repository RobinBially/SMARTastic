// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "SMARTastic",
    defaultLocalization: "de",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "SMARTastic",
            resources: [.process("Resources")]
        )
    ]
)
