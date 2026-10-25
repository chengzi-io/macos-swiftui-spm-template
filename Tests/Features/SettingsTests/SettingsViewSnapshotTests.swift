import AppKit
import Platform
import SnapshotSupport
import SnapshotTesting
import Testing

@testable import SettingsFeature

/// The panes, not `SettingsView`: the toolbar's tabs belong to the Settings window, which
/// an off-screen render has none of.
@MainActor
@Suite(.snapshots(record: recording))
struct SettingsViewSnapshotTests {
    @Test func updates() throws {
        assertSnapshot(of: try render(updatesPane()), as: .image(perceptualPrecision: 0.98))
    }

    @Test func updatesDark() throws {
        assertSnapshot(of: try render(updatesPane(), appearance: .darkAqua), as: .image(perceptualPrecision: 0.98))
    }

    private func updatesPane() -> UpdatesSettingsView {
        UpdatesSettingsView(updater: MockUpdaterService(), version: "1.2.0 (345)")
    }
}
