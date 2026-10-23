// swift-tools-version: 6.2
import PackageDescription

// Services run wherever their caller does; UI modules default to MainActor.
let common: [SwiftSetting] = [
    .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
    .enableUpcomingFeature("InferIsolatedConformances"),
    .enableUpcomingFeature("MemberImportVisibility"),
    // Xcode builds a package added with "Add Local…" (XCLocalSwiftPackageReference)
    // with -suppress-warnings, which conflicts with this. App.xcodeproj references the
    // package folder instead, which Xcode builds with warnings on.
    .treatAllWarnings(as: .error),
]
let ui = common + [.defaultIsolation(MainActor.self)]

let package = Package(
    name: "AppModules",
    defaultLocalization: "en",
    platforms: [.macOS(.v14)],
    products: [
        // Linked by the Xcode app target, the composition root.
        .library(name: "AppRoot", targets: ["AppRoot"]),
        .library(name: "Services", targets: ["Services"]),
        .library(name: "ServicesLive", targets: ["ServicesLive"]),
    ],
    dependencies: [
        .package(url: "https://github.com/sparkle-project/Sparkle", exact: "2.10.0"),
        .package(url: "https://github.com/pointfreeco/swift-snapshot-testing", exact: "1.19.6"),
    ],
    targets: [
        .target(
            name: "AppRoot",
            dependencies: ["GreetingFeature", "SettingsFeature", "Services"],
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
            dependencies: ["Services"],
            path: "Sources/Features/Settings",
            resources: [.process("Resources")],
            swiftSettings: ui
        ),
        .target(
            name: "Services",
            swiftSettings: common
        ),
        .target(
            name: "ServicesLive",
            dependencies: ["Services", .product(name: "Sparkle", package: "Sparkle")],
            swiftSettings: common
        ),
        .testTarget(
            name: "GreetingFeatureTests",
            dependencies: [
                "GreetingFeature",
                .product(name: "SnapshotTesting", package: "swift-snapshot-testing"),
            ],
            path: "Tests/Features/GreetingTests",
            swiftSettings: ui
        ),
    ]
)
