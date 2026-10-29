# AppKit bridges

SwiftUI comes first. When no public SwiftUI API does the job, including APIs behind
`#available` (the app targets macOS 14), bridge at the layer that is missing. Go down a
step only when the step above cannot do it:

1. **A view SwiftUI lacks**, such as rich text in `NSTextView` or an `NSTableView` with
   100,000 rows: wrap it in `NSViewRepresentable`, or in `NSViewControllerRepresentable`
   for a view controller. The scene stays SwiftUI. Delegates go on the coordinator, and
   `dismantleNSView` removes observers and timers.
2. **A window property you set once**: read the hosting `NSWindow` and set the property.
   This is also how macOS 14 gets a newer modifier, such as `windowLevel(_:)` or
   `windowMinimizeBehavior(_:)` (both macOS 15+). It holds only while SwiftUI leaves the
   property alone, so check it again after the window reopens.
3. **The window's structure**, such as a sidebar that cannot collapse, the toolbar's
   layout, the line under the toolbar, or an `NSPanel`: AppKit owns the window, and
   SwiftUI fills it.

Move to step 3 when SwiftUI keeps resetting what step 2 set, or when the workaround
starts to depend on timing, notifications or delays. Never swizzle, call private API or
poll to reapply a value.

Steps 1 and 2 are representables, and they live in an `AppKitBridge` target that
features depend on (`make lint` rejects them in a feature). It is a kit: it knows
nothing of the app. Create it the first time: `Sources/Kits/AppKitBridge/`, and in
`Package.swift`
`.target(name: "AppKitBridge", path: "Sources/Kits/AppKitBridge", swiftSettings: ui)`.

Step 2 reads the window from a view placed in it:

```swift
import AppKit
import SwiftUI

/// Hands the window that hosts this view to `configure` once the view is in it.
public struct WindowReader: NSViewRepresentable {
    let configure: (NSWindow) -> Void

    public init(configure: @escaping (NSWindow) -> Void) {
        self.configure = configure
    }

    public func makeNSView(context: Context) -> ReaderView { ReaderView(configure: configure) }
    public func updateNSView(_ nsView: ReaderView, context: Context) {}

    public final class ReaderView: NSView {
        let configure: (NSWindow) -> Void

        init(configure: @escaping (NSWindow) -> Void) {
            self.configure = configure
            super.init(frame: .zero)
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

        override public func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            if let window { configure(window) }
        }
    }
}

// <Name>View(model: model).background(WindowReader { $0.level = .floating })
```

Step 3 is an `NSWindowController` in `AppRoot`, which owns the windows, with each column
an `NSHostingController`. Here the split view belongs to the app, so its sidebar stays
fixed:

```swift
final class SidebarWindowController: NSWindowController {
    init(model: AppModel) {
        let sidebar = NSSplitViewItem(
            sidebarWithViewController: NSHostingController(rootView: Sidebar(model: model))
        )
        sidebar.canCollapse = false
        sidebar.minimumThickness = 215
        sidebar.maximumThickness = 215
        let split = NSSplitViewController()
        split.addSplitViewItem(sidebar)
        let detail = NSHostingController(rootView: Detail(model: model))
        split.addSplitViewItem(NSSplitViewItem(viewController: detail))

        // Without .miniaturizable and .resizable, minimize and zoom are dimmed.
        let window = NSWindow(
            contentRect: .zero,
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: true
        )
        window.contentViewController = split
        window.setContentSize(NSSize(width: 715, height: 600))
        super.init(window: window)
        // On the controller: `init(window:)` clears a name set on the window.
        windowFrameAutosaveName = "Settings"
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}
```

Owning the window costs this:

- The scene's environment does not cross into an `NSHostingController`. Models already
  reach views through their initializers, so pass the model to each hosted root view.
- AppKit observes the same `@Observable` model with `withObservationTracking`. It fires
  once, so register again in `onChange`, on the main actor.
- Build the toolbar with `NSToolbar`. When SwiftUI's `.toolbar` built it from a hosted
  view, the window's first title came out unlocalized.
- `SettingsLink`, `openSettings` and `openWindow` cannot open the window. The app keeps
  the controller and shows it from its menu commands.
- AppKit and SwiftUI do not always stay in sync. For example, the automatic line under
  the toolbar stopped tracking the scroll position once SwiftUI replaced the pane's
  content, so check each macOS release.

Settings with a vertical sidebar is a step 3 case. The `Settings` scene keeps the
preferences toolbar, so the title stays centered. A `NavigationSplitView` sidebar
collapses when its divider is dragged in. UserDefaults saves the collapsed state
(`NSSplitView Subview Frames …`) and restores it on the next launch. Once the sidebar
toggle is removed, nothing brings the sidebar back. Either keep the toggle (a `Window`
scene with `NavigationSplitView`) or own the window as above. This was checked on
macOS 15.7.
