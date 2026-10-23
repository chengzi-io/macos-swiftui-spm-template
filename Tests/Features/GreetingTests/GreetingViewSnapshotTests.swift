import AppKit
import Foundation
import SnapshotTesting
import SwiftUI
import Testing

@testable import GreetingFeature

/// A plain test run never writes a reference, so a missing or changed image fails.
/// `make snapshots` records, with SNAPSHOT_TESTING_RECORD=failed.
private nonisolated let recording =
    ProcessInfo.processInfo.environment["SNAPSHOT_TESTING_RECORD"]
    .flatMap(SnapshotTestingConfiguration.Record.init(rawValue:)) ?? .never

@MainActor
@Suite(.snapshots(record: recording))
struct GreetingViewSnapshotTests {
    @Test func empty() throws {
        assertSnapshot(of: try render(GreetingView(model: GreetingModel())), as: .image(perceptualPrecision: 0.98))
    }

    @Test func greeted() throws {
        assertSnapshot(of: try render(GreetingView(model: greetedModel())), as: .image(perceptualPrecision: 0.98))
    }

    @Test func greetedDark() throws {
        assertSnapshot(
            of: try render(GreetingView(model: greetedModel()), appearance: .darkAqua),
            as: .image(perceptualPrecision: 0.98)
        )
    }

    private func greetedModel() -> GreetingModel {
        let model = GreetingModel()
        model.name = "Ada"
        model.greet()
        return model
    }

    /// Renders at 2x on every Mac, whatever the main display's scale: a CI runner's
    /// virtual display would otherwise give 1x images.
    private func render(_ view: some View, appearance: NSAppearance.Name = .aqua) throws -> NSImage {
        // Outside a window nothing draws the window background, and dark text would sit on
        // transparent pixels.
        let hosting = NSHostingView(rootView: view.background(Color(nsColor: .windowBackgroundColor)))
        hosting.appearance = NSAppearance(named: appearance)
        let size = hosting.fittingSize
        hosting.frame = CGRect(origin: .zero, size: size)
        let bitmap = try #require(
            NSBitmapImageRep(
                bitmapDataPlanes: nil,
                pixelsWide: Int(size.width * 2),
                pixelsHigh: Int(size.height * 2),
                bitsPerSample: 8,
                samplesPerPixel: 4,
                hasAlpha: true,
                isPlanar: false,
                colorSpaceName: .deviceRGB,
                bytesPerRow: 0,
                bitsPerPixel: 0
            )
        )
        bitmap.size = size
        hosting.cacheDisplay(in: hosting.bounds, to: bitmap)
        let image = NSImage(size: size)
        image.addRepresentation(bitmap)
        return image
    }
}
