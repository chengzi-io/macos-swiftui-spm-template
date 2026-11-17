import AppKit
import Foundation
import Observation
import Platform
import SwiftUI

/// Settings in an AppKit window around an `NSSplitViewController`, as System Settings
/// looks, rather than in the `Settings` scene: that scene keeps the preferences toolbar,
/// and a `NavigationSplitView` sidebar collapses when its divider is dragged in. This
/// split view belongs to the app, so the sidebar keeps its width. Both columns are SwiftUI.
/// `SettingsLink` and `openSettings` do not open this window; `show(_:)` does.
public final class SettingsWindowController: NSWindowController, NSToolbarDelegate, NSToolbarItemValidation {
    private static let back = NSToolbarItem.Identifier("back")
    private static let forward = NSToolbarItem.Identifier("forward")

    private let navigation: SettingsNavigation
    private let detailItem: NSSplitViewItem

    public init(updater: any UpdaterService) {
        // The pane last used, as the HIG asks; `SettingsDetail` writes it.
        let lastPane = UserDefaults.standard.string(forKey: SettingsPane.storageKey).flatMap(SettingsPane.init)
        let navigation = SettingsNavigation(pane: lastPane ?? SettingsPane.allCases[0])
        self.navigation = navigation
        let sidebar = NSSplitViewItem(
            sidebarWithViewController: NSHostingController(rootView: SettingsSidebar(navigation: navigation))
        )
        sidebar.canCollapse = false
        sidebar.minimumThickness = 215
        sidebar.maximumThickness = 215
        let detail = NSHostingController(
            rootView: SettingsDetail(navigation: navigation, updater: updater)
        )
        // The pane's navigation title becomes the window's title.
        detail.sceneBridgingOptions = [.title]
        detailItem = NSSplitViewItem(viewController: detail)
        let split = NSSplitViewController()
        split.addSplitViewItem(sidebar)
        split.addSplitViewItem(detailItem)

        // Without .miniaturizable and .resizable, minimize and zoom are dimmed.
        let window = NSWindow(
            contentRect: .zero,
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: true
        )
        // Set after init: `NSWindow(contentViewController:)` leaves the title "Untitled"
        // until the pane changes.
        window.contentViewController = split
        // System Settings' width; a fixed height that leaves room on a 13-inch screen.
        window.setContentSize(NSSize(width: 715, height: 600))
        window.center()
        super.init(window: window)
        // On the controller: `init(window:)` clears a name set on the window. A window that
        // cannot be resized gets back only its saved position.
        windowFrameAutosaveName = "Settings"

        // AppKit items: when SwiftUI's toolbar bridging built the toolbar, the window's
        // first title came out unlocalized.
        let toolbar = NSToolbar()
        toolbar.delegate = self
        window.toolbar = toolbar
        // One row high, with the buttons and the title over the pane.
        window.toolbarStyle = .unifiedCompact
        showsSeparatorWhenScrolled()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// Brings the window forward, switched to `pane` when one is given.
    public func show(_ pane: SettingsPane? = nil) {
        if let pane { navigation.open(pane) }
        showWindow(nil)
    }

    /// The line under the toolbar shows only while the pane is scrolled, as in System
    /// Settings. AppKit's automatic style loses track once SwiftUI swaps the pane's form
    /// and then keeps the line, so the pane's scroll offset drives it instead. On macOS 14,
    /// which cannot report the offset, the line never shows.
    private func showsSeparatorWhenScrolled() {
        detailItem.titlebarSeparatorStyle = navigation.isScrolled ? .line : .none
        withObservationTracking {
            _ = navigation.isScrolled
        } onChange: {
            Task { @MainActor [weak self] in self?.showsSeparatorWhenScrolled() }
        }
    }

    public func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        [.sidebarTrackingSeparator, Self.back, Self.forward]
    }

    public func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        toolbarDefaultItemIdentifiers(toolbar)
    }

    public func toolbar(
        _ toolbar: NSToolbar,
        itemForItemIdentifier identifier: NSToolbarItem.Identifier,
        willBeInsertedIntoToolbar flag: Bool
    ) -> NSToolbarItem? {
        let isBack = identifier == Self.back
        let label = isBack ? String(localized: "Back", bundle: .module) : String(localized: "Forward", bundle: .module)
        let item = NSToolbarItem(itemIdentifier: identifier)
        item.label = label
        item.image = NSImage(
            systemSymbolName: isBack ? "chevron.left" : "chevron.right", accessibilityDescription: label)
        item.isBordered = true
        item.isNavigational = true
        item.target = self
        item.action = isBack ? #selector(goBack) : #selector(goForward)
        return item
    }

    public func validateToolbarItem(_ item: NSToolbarItem) -> Bool {
        item.itemIdentifier == Self.back ? navigation.canGoBack : navigation.canGoForward
    }

    @objc private func goBack() {
        navigation.goBack()
    }

    @objc private func goForward() {
        navigation.goForward()
    }
}

/// The app menu's Settings… item (⌘,), which the `Settings` scene would otherwise provide.
public struct SettingsCommand: View {
    private let open: () -> Void

    public init(open: @escaping () -> Void) {
        self.open = open
    }

    public var body: some View {
        Button(action: open) {
            Text("Settings…", bundle: .module)
        }
        .keyboardShortcut(",")
    }
}

#Preview {
    SettingsCommand {}
        .padding()
}
