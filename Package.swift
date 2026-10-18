// swift-tools-version: 6.2
import PackageDescription

let swiftSettings: [SwiftSetting] = [
    .defaultIsolation(MainActor.self),
    .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
    .enableUpcomingFeature("InferIsolatedConformances"),
    .treatAllWarnings(as: .error),
]

let package = Package(
    name: "App",
    defaultLocalization: "en",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "App",
            dependencies: ["AppCore"],
            swiftSettings: swiftSettings
        ),
        .target(
            name: "AppCore",
            resources: [.process("Resources")],
            swiftSettings: swiftSettings
        ),
        .testTarget(
            name: "AppCoreTests",
            dependencies: ["AppCore"],
            swiftSettings: swiftSettings
        ),
    ]
)
