import AppKit
import Platform
import RenderSupport
import Testing

@testable import SettingsFeature

/// The panes, not `SettingsView`: the toolbar's tabs belong to the Settings window, which
/// an off-screen render has none of.
@MainActor
struct SettingsViewRenderTests {
    @Test func updates() throws {
        try render(updatesPane())
    }

    @Test func updatesDark() throws {
        try render(updatesPane(), appearance: .darkAqua)
    }

    private func updatesPane() -> UpdatesSettingsView {
        UpdatesSettingsView(updater: MockUpdaterService(), version: "1.2.0 (345)")
    }
}
