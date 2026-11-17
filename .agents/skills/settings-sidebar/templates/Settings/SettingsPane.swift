import Foundation

/// The panes in the settings sidebar, in order. The raw value is what UserDefaults keeps
/// under `storageKey`, so Settings opens on the pane last used.
public enum SettingsPane: String, CaseIterable, Identifiable, Sendable {
    case updates

    static let storageKey = "settingsPane"

    public var id: Self { self }

    var title: String {
        switch self {
        case .updates: String(localized: "Updates", bundle: .module)
        }
    }

    var symbol: String {
        switch self {
        case .updates: "arrow.triangle.2.circlepath"
        }
    }

    /// The labels of the pane's settings, so a search finds the pane by them too. A
    /// setting added to a pane adds its label here.
    var keywords: [String] {
        switch self {
        case .updates:
            [
                String(localized: "Version", bundle: .module),
                String(localized: "Automatically check for updates", bundle: .module),
                String(localized: "Check for Updates…", bundle: .module),
            ]
        }
    }

    /// Every pane for a blank query; otherwise the panes whose title or keywords contain it.
    static func matching(_ query: String) -> [SettingsPane] {
        let query = query.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return allCases }
        return allCases.filter { pane in
            ([pane.title] + pane.keywords).contains { $0.localizedStandardContains(query) }
        }
    }
}
