import Foundation
import Platform
import PlatformLive
import Testing

private enum Size: Int, PreferenceValue {
    case small = 1
    case large = 2
}

private struct Window: CodablePreferenceValue, Equatable {
    var width: Int
    var title: String
}

extension PreferenceKey where Value == Bool {
    fileprivate static var flag: Self { Self("flag", default: true) }
}

extension PreferenceKey where Value == String {
    fileprivate static var name: Self { Self("name", default: "Pomelo") }
}

extension PreferenceKey where Value == Size {
    fileprivate static var size: Self { Self("size", default: .small) }
}

extension PreferenceKey where Value == Window {
    fileprivate static var window: Self { Self("window", default: Window(width: 400, title: "Default")) }
}

/// The live store against a throwaway UserDefaults suite, which each test empties again,
/// and the mock, which must convert values the same way. One suite name, serialized: a
/// removed domain still leaves its empty plist in ~/Library/Preferences, and a name per
/// test would leave one per run.
@MainActor
@Suite(.serialized)
final class PreferencesStoreTests {
    private let suite = "io.chengzi.Pomelo.PreferencesStoreTests"
    private let defaults: UserDefaults

    init() throws {
        defaults = try #require(UserDefaults(suiteName: suite))
        // A crashed run leaves its values behind.
        defaults.removePersistentDomain(forName: suite)
    }

    deinit {
        // Any instance removes a domain by name; `defaults` is not Sendable, and deinit
        // is nonisolated.
        UserDefaults().removePersistentDomain(forName: suite)
    }

    @Test(arguments: [Store.mock, .live])
    func unsetKeysReadTheirDefaults(store: Store) {
        let preferences = make(store)
        #expect(preferences[.flag] == true)
        #expect(preferences[.name] == "Pomelo")
        #expect(preferences[.size] == .small)
        #expect(preferences[.window] == Window(width: 400, title: "Default"))
        #expect(preferences[.appearance] == .system)
    }

    @Test(arguments: [Store.mock, .live])
    func valuesRoundTrip(store: Store) {
        let preferences = make(store)
        preferences[.flag] = false
        preferences[.name] = "Grapefruit"
        preferences[.size] = .large
        preferences[.window] = Window(width: 715, title: "Settings")
        preferences[.appearance] = .dark
        #expect(preferences[.flag] == false)
        #expect(preferences[.name] == "Grapefruit")
        #expect(preferences[.size] == .large)
        #expect(preferences[.window] == Window(width: 715, title: "Settings"))
        #expect(preferences[.appearance] == .dark)
    }

    @Test(arguments: [Store.mock, .live])
    func removingAValueRestoresTheDefault(store: Store) {
        let preferences = make(store)
        preferences[.size] = .large
        preferences.removeValue(for: .size)
        #expect(preferences[.size] == .small)
    }

    @Test(arguments: [Store.mock, .live])
    func anUnreadableValueReadsTheDefault(store: Store) {
        let preferences = make(store, stored: ["appearance": "sepia", "size": "large", "window": Data("{}".utf8)])
        #expect(preferences[.appearance] == .system)
        #expect(preferences[.size] == .small)
        #expect(preferences[.window] == Window(width: 400, title: "Default"))
    }

    @Test func liveStoresRawValuesUnderTheKeyName() {
        let preferences = LivePreferencesStore(defaults: defaults)
        preferences[.appearance] = .dark
        preferences[.size] = .large
        #expect(defaults.string(forKey: "appearance") == "dark")
        #expect(defaults.integer(forKey: "size") == 2)
    }

    /// The key is the one LiveAppearanceService wrote, so an earlier choice carries over.
    @Test func liveReadsAValueStoredBeforeTheStore() {
        defaults.set("light", forKey: "appearance")
        #expect(LivePreferencesStore(defaults: defaults)[.appearance] == .light)
    }

    enum Store: CustomTestStringConvertible {
        case mock
        case live

        var testDescription: String {
            switch self {
            case .mock: "mock"
            case .live: "live"
            }
        }
    }

    private func make(_ store: Store, stored: [String: Any] = [:]) -> any PreferencesStore {
        switch store {
        case .mock:
            return MockPreferencesStore(values: stored)
        case .live:
            for (name, value) in stored { defaults.set(value, forKey: name) }
            return LivePreferencesStore(defaults: defaults)
        }
    }
}
