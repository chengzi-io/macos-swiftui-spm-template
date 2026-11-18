/// Light or dark for this app only, or whatever the Mac is set to.
public enum Appearance: String, CaseIterable, Sendable, PreferenceValue {
    case system
    case light
    case dark
}

extension PreferenceKey where Value == Appearance {
    /// The user's choice in Settings; the name predates the store, so keep it.
    public static var appearance: Self { Self("appearance", default: .system) }
}

/// Applies an appearance to the whole app. It stores nothing: the choice is the
/// `.appearance` preference.
@MainActor
public protocol AppearanceService: AnyObject {
    func apply(_ appearance: Appearance)
}

/// Stands in for the live service in previews, tests and UI test launches; it changes
/// nothing on screen and records what it was asked to apply.
@MainActor
public final class MockAppearanceService: AppearanceService {
    public private(set) var applied: [Appearance] = []

    public init() {}

    public func apply(_ appearance: Appearance) {
        applied.append(appearance)
    }
}
