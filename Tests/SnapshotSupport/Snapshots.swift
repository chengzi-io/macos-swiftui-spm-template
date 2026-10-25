import AppKit
import Foundation
import SnapshotTesting
import SwiftUI
import Testing

/// A plain test run never writes a reference, so a missing or changed image fails.
/// `make snapshots` records, with SNAPSHOT_TESTING_RECORD=failed. Suites take it as
/// `@Suite(.snapshots(record: recording))`.
public nonisolated let recording =
    ProcessInfo.processInfo.environment["SNAPSHOT_TESTING_RECORD"]
    .flatMap(SnapshotTestingConfiguration.Record.init(rawValue:)) ?? .never

/// Renders at 2x on every Mac, whatever the main display's scale: a CI runner's virtual
/// display would otherwise give 1x images.
public func render(_ view: some View, appearance: NSAppearance.Name = .aqua) throws -> NSImage {
    // Controls draw in the Mac's accent color, so a Mac set to purple would record purple
    // checkboxes. Pin blue (4), what an unset accent draws on a CI runner, for this
    // process only.
    var arguments = UserDefaults.standard.volatileDomain(forName: UserDefaults.argumentDomain)
    arguments["AppleAccentColor"] = 4
    UserDefaults.standard.setVolatileDomain(arguments, forName: UserDefaults.argumentDomain)
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
