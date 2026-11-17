import Observation

/// The settings window's pane and its back and forward history, as in System Settings.
/// The sidebar and the pane are separate hosting controllers; both get this instance.
@Observable
final class SettingsNavigation {
    private var history: [SettingsPane]
    private var index = 0
    /// Whether the pane is scrolled under the toolbar, which then draws its bottom line.
    var isScrolled = false

    var pane: SettingsPane { history[index] }

    init(pane: SettingsPane = SettingsPane.allCases[0]) {
        history = [pane]
    }
    var canGoBack: Bool { index > 0 }
    var canGoForward: Bool { index < history.count - 1 }

    /// Opening a pane drops the panes ahead of the current one, as a browser does.
    func open(_ pane: SettingsPane) {
        guard pane != self.pane else { return }
        history.removeSubrange((index + 1)...)
        history.append(pane)
        index += 1
    }

    func goBack() {
        guard canGoBack else { return }
        index -= 1
    }

    func goForward() {
        guard canGoForward else { return }
        index += 1
    }
}
