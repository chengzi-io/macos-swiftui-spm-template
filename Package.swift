// swift-tools-version: 6.2
import PackageDescription

let swiftSettings: [SwiftSetting] = [
    .defaultIsolation(MainActor.self),
    .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
    .enableUpcomingFeature("InferIsolatedConformances"),
    .treatAllWarnings(as: .error),
]

// `make release-mas` sets APP_STORE=1: the App Store updates the app, so Sparkle is left out.
let appStore = Context.environment["APP_STORE"] == "1"

let package = Package(
    name: "App",
    defaultLocalization: "en",
    platforms: [.macOS(.v14)],
    dependencies: appStore
        ? []
        : [
            .package(url: "https://github.com/sparkle-project/Sparkle", exact: "2.10.0")
        ],
    targets: [
        .executableTarget(
            name: "App",
            dependencies: ["AppCore"] + (appStore ? [] : [.product(name: "Sparkle", package: "Sparkle")]),
            swiftSettings: swiftSettings + (appStore ? [.define("APP_STORE")] : []),
            linkerSettings: [
                // Embedded frameworks (Sparkle) live in Contents/Frameworks.
                .unsafeFlags(["-Xlinker", "-rpath", "-Xlinker", "@executable_path/../Frameworks"])
            ]
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
