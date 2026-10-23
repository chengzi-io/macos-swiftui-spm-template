import AppKit
import Foundation
import SnapshotTesting
import SwiftUI
import Testing

@testable import GreetingFeature

// References are images of this Mac's controls; another macOS version draws them
// differently, so CI, on another version, skips them.
@MainActor
@Suite(.disabled(if: ProcessInfo.processInfo.environment["CI"] != nil, "references come from the developer's macOS"))
struct GreetingViewSnapshotTests {
    @Test func empty() {
        assertSnapshot(of: hosting(GreetingView(model: GreetingModel())), as: .image)
    }

    @Test func greeted() {
        assertSnapshot(of: hosting(GreetingView(model: greetedModel())), as: .image)
    }

    @Test func greetedDark() {
        assertSnapshot(of: hosting(GreetingView(model: greetedModel()), appearance: .darkAqua), as: .image)
    }

    private func greetedModel() -> GreetingModel {
        let model = GreetingModel()
        model.name = "Ada"
        model.greet()
        return model
    }

    private func hosting(_ view: some View, appearance: NSAppearance.Name = .aqua) -> NSView {
        // Outside a window nothing draws the window background, and dark text would sit on
        // transparent pixels.
        let hosting = NSHostingView(rootView: view.background(Color(nsColor: .windowBackgroundColor)))
        hosting.appearance = NSAppearance(named: appearance)
        hosting.frame = CGRect(origin: .zero, size: hosting.fittingSize)
        return hosting
    }
}
