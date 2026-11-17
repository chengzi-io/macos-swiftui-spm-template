import Platform
import SwiftUI

/// The selected pane. `SettingsWindowController` puts the sidebar beside it and makes its
/// navigation title the window's.
struct SettingsDetail: View {
    @AppStorage(SettingsPane.storageKey) private var lastPane = SettingsPane.allCases[0]
    let navigation: SettingsNavigation
    let updater: any UpdaterService

    var body: some View {
        Group {
            switch navigation.pane {
            case .updates:
                UpdatesSettingsView(updater: updater)
            }
        }
        .clearScrollBackgroundOnMacOS26()
        .onScrolledChange { navigation.isScrolled = $0 }
        .navigationTitle(navigation.pane.title)
        .onChange(of: navigation.pane) { lastPane = $1 }
    }
}

extension View {
    /// Reports whether the content is scrolled under the toolbar. macOS 14 cannot read the
    /// scroll offset and reports nothing.
    @ViewBuilder
    fileprivate func onScrolledChange(_ action: @escaping (Bool) -> Void) -> some View {
        if #available(macOS 15.0, *) {
            onScrollGeometryChange(for: Bool.self) {
                $0.contentOffset.y + $0.contentInsets.top > 0
            } action: {
                action($1)
            }
        } else {
            self
        }
    }

    /// macOS 26 shows the window's background behind the form. Earlier releases keep the
    /// form's own: without it macOS 15 draws a band under the toolbar.
    @ViewBuilder
    fileprivate func clearScrollBackgroundOnMacOS26() -> some View {
        if #available(macOS 26.0, *) {
            scrollContentBackground(.hidden)
        } else {
            self
        }
    }
}

#Preview {
    SettingsDetail(navigation: SettingsNavigation(), updater: MockUpdaterService())
        .frame(width: 500, height: 400)
}
