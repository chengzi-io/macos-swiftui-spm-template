import AppKit
import SwiftUI

// Renders DMGBackground (Bundle/DMG/Background.swift) to background.png and
// background@2x.png in the given directory.
@main
struct RenderDMGBackground {
    @MainActor static func main() throws {
        let directory = URL(fileURLWithPath: CommandLine.arguments[1])
        for (scale, name) in [(1.0, "background.png"), (2.0, "background@2x.png")] {
            let renderer = ImageRenderer(content: DMGBackground())
            renderer.scale = scale
            guard let image = renderer.cgImage else {
                throw CocoaError(.fileWriteUnknown, userInfo: [NSLocalizedDescriptionKey: "cannot render \(name)"])
            }
            let bitmap = NSBitmapImageRep(cgImage: image)
            // 144 dpi on the @2x file, so Finder treats it as the Retina variant.
            bitmap.size = DMGBackground.size
            guard let png = bitmap.representation(using: .png, properties: [:]) else {
                throw CocoaError(.fileWriteUnknown, userInfo: [NSLocalizedDescriptionKey: "cannot encode \(name)"])
            }
            try png.write(to: directory.appending(path: name))
        }
    }
}
