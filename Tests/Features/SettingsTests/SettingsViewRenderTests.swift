import AppKit
import Platform
import RenderSupport
import Testing

@testable import SettingsFeature

/// The panes, not `SettingsView`: the toolbar's tabs belong to the Settings window, which
/// an off-screen render has none of.
@MainActor
struct SettingsViewRenderTests {
    @Test func general() throws {
        try render(settings())
    }

    @Test func generalDark() throws {
        try render(settings(), appearance: .darkAqua)
    }

    @Test func generalChinese() throws {
        try render(settings(languageIdentifier: "zh-Hans"))
    }

    private func settings(languageIdentifier: String = "en") -> GeneralSettingsView {
        let model = SettingsModel(
            updater: MockUpdaterService(),
            preferences: MockPreferencesStore(),
            appearance: MockAppearanceService(),
            languageIdentifier: languageIdentifier
        )
        return GeneralSettingsView(model: model, version: "1.2.0 (345)")
    }
}
