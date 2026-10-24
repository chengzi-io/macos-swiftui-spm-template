// swift-tools-version: 6.2
import PackageDescription

// Domain and Platform modules run wherever their caller does; UI modules default to
// MainActor.
let common: [SwiftSetting] = [
    .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
    .enableUpcomingFeature("InferIsolatedConformances"),
    .enableUpcomingFeature("MemberImportVisibility"),
    // Xcode builds a package added with "Add Local…" (XCLocalSwiftPackageReference)
    // with -suppress-warnings, which conflicts with this. App/<App>.xcodeproj
    // references this folder instead, which Xcode builds with warnings on.
    .treatAllWarnings(as: .error),
]
let ui = common + [.defaultIsolation(MainActor.self)]

let package = Package(
    name: "Pomelo",
    defaultLocalization: "en",
    platforms: [.macOS(.v14)],
    products: [
        // Linked by the Xcode app target, the composition root.
        .library(name: "AppRoot", targets: ["AppRoot"]),
        .library(name: "Platform", targets: ["Platform"]),
        .library(name: "PlatformLive", targets: ["PlatformLive"]),
    ],
    dependencies: [
        .package(url: "https://github.com/sparkle-project/Sparkle", exact: "2.10.0"),
        .package(url: "https://github.com/pointfreeco/swift-snapshot-testing", exact: "1.19.6"),
    ],
    targets: [
        .target(
            name: "AppRoot",
            dependencies: ["GreetingFeature", "SettingsFeature", "Platform"],
            resources: [.process("Resources")],
            swiftSettings: ui
        ),
        .target(
            name: "GreetingFeature",
            path: "Sources/Features/Greeting",
            resources: [.process("Resources")],
            swiftSettings: ui
        ),
        .target(
            name: "SettingsFeature",
            dependencies: ["Platform"],
            path: "Sources/Features/Settings",
            resources: [.process("Resources")],
            swiftSettings: ui
        ),
        .target(
            name: "Platform",
            path: "Sources/Platform/Core",
            swiftSettings: common
        ),
        .target(
            name: "PlatformLive",
            dependencies: ["Platform", .product(name: "Sparkle", package: "Sparkle")],
            path: "Sources/Platform/Live",
            swiftSettings: common
        ),
        .testTarget(
            name: "GreetingFeatureTests",
            dependencies: [
                "GreetingFeature",
                .product(name: "SnapshotTesting", package: "swift-snapshot-testing"),
            ],
            path: "Tests/Features/GreetingTests",
            exclude: ["__Snapshots__"],
            swiftSettings: ui
        ),
    ]
)
