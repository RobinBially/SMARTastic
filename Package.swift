// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "SMARTastic",
    defaultLocalization: "en",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "SMARTastic",
            resources: [.process("Resources")]
        ),
        .testTarget(name: "SMARTasticTests", dependencies: ["SMARTastic"])
    ]
)
