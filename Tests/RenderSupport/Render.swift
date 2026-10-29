import AppKit
import Foundation
import SwiftUI
import Testing

/// Draws the view and writes it to `.build/renders/<test file>/<test>.png`, for an agent
/// or a person to look at. Nothing compares the image; each run replaces it.
///
/// Renders at 2x on every Mac, whatever the main display's scale: a CI runner's virtual
/// display would otherwise give 1x images.
public func render(
    _ view: some View,
    appearance: NSAppearance.Name = .aqua,
    filePath: String = #filePath,
    function: String = #function
) throws {
    // Controls follow the Mac's settings, so a Mac set to a purple accent or to always
    // show scroll bars would draw them. Pin what a CI runner draws, for this process
    // only: the blue accent (4) and scroll bars only while scrolling.
    var arguments = UserDefaults.standard.volatileDomain(forName: UserDefaults.argumentDomain)
    arguments["AppleAccentColor"] = 4
    arguments["AppleShowScrollBars"] = "WhenScrolling"
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
    let png = try #require(bitmap.representation(using: .png, properties: [:]))

    let file = URL(filePath: filePath)
    var root = file.deletingLastPathComponent()
    while root.lastPathComponent != "Tests" {
        try #require(root.pathComponents.count > 1, "\(filePath) is not under Tests/")
        root.deleteLastPathComponent()
    }
    let directory = root.deletingLastPathComponent()
        .appending(path: ".build/renders/\(file.deletingPathExtension().lastPathComponent)")
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    try png.write(to: directory.appending(path: "\(function.prefix { $0 != "(" }).png"))
}
