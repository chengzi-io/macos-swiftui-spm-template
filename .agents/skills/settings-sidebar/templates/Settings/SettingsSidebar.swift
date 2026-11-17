import AppKitBridge
import SwiftUI

struct SettingsSidebar: View {
    let navigation: SettingsNavigation
    @State private var query = ""
    @FocusState private var listFocused: Bool

    var body: some View {
        // The field sits above the list, as in System Settings, so it stays put while the
        // rows scroll; `.searchable(placement: .sidebar)` would make it the first row.
        VStack(spacing: 0) {
            SearchField(text: $query)
                // System Settings' size and insets.
                .controlSize(.large)
                .padding([.horizontal, .bottom], 8)
            List(SettingsPane.matching(query), selection: selection) { pane in
                Label {
                    Text(pane.title)
                } icon: {
                    Image(systemName: pane.symbol)
                }
            }
            .listStyle(.sidebar)
            .softScrollEdgeOnMacOS26()
            // System Settings opens with the list focused; the window alone would pick
            // the search field, its first key view. ⌘F reaches the field.
            .focused($listFocused)
            .onAppear { listFocused = true }
        }
    }

    /// Command-clicking the selected row writes nil; keep the current pane instead.
    private var selection: Binding<SettingsPane?> {
        Binding {
            navigation.pane
        } set: {
            if let pane = $0 { navigation.open(pane) }
        }
    }
}

extension View {
    /// Rows fade out under the toolbar on macOS 26.
    @ViewBuilder
    fileprivate func softScrollEdgeOnMacOS26() -> some View {
        if #available(macOS 26.0, *) {
            scrollEdgeEffectStyle(.soft, for: .all)
        } else {
            self
        }
    }
}

#Preview {
    SettingsSidebar(navigation: SettingsNavigation())
        .frame(width: 215, height: 400)
}
