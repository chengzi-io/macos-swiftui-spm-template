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
        // The one product the Xcode app target links: every module MainApp imports. A new
        // domain's targets join it here, so the Xcode project never changes.
        .library(name: "AppModules", targets: ["AppRoot", "Notes", "NotesLive", "Platform", "PlatformLive"])
    ],
    dependencies: [
        .package(url: "https://github.com/sparkle-project/Sparkle", exact: "2.10.0"),
        .package(url: "https://github.com/pointfreeco/swift-snapshot-testing", exact: "1.19.6"),
    ],
    targets: [
        .target(
            name: "AppRoot",
            dependencies: ["NotesFeature", "SettingsFeature", "Notes", "Platform"],
            swiftSettings: ui
        ),
        .target(
            name: "NotesFeature",
            dependencies: ["Notes"],
            path: "Sources/Features/Notes",
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
            name: "Notes",
            path: "Sources/Notes/Core",
            swiftSettings: common
        ),
        .target(
            name: "NotesLive",
            dependencies: ["Notes"],
            path: "Sources/Notes/Live",
            swiftSettings: common
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
        // The test targets' view renderer; nothing in the app depends on it.
        .target(
            name: "SnapshotSupport",
            dependencies: [.product(name: "SnapshotTesting", package: "swift-snapshot-testing")],
            path: "Tests/SnapshotSupport",
            swiftSettings: ui
        ),
        .testTarget(
            name: "NotesFeatureTests",
            dependencies: [
                "NotesFeature",
                "Notes",
                "SnapshotSupport",
                .product(name: "SnapshotTesting", package: "swift-snapshot-testing"),
            ],
            path: "Tests/Features/NotesTests",
            exclude: ["__Snapshots__"],
            swiftSettings: ui
        ),
        .testTarget(
            name: "SettingsFeatureTests",
            dependencies: [
                "SettingsFeature",
                "Platform",
                "SnapshotSupport",
                .product(name: "SnapshotTesting", package: "swift-snapshot-testing"),
            ],
            path: "Tests/Features/SettingsTests",
            exclude: ["__Snapshots__"],
            swiftSettings: ui
        ),
    ]
)
