import AppKit

// Writes the icon macOS shows for a file (the Finder and Dock icon) as a PNG of
// <points> at the screen's scale (64 px for 32 pt on Retina).
// usage: render-icon.swift <path> <out.png> <points>
let args = CommandLine.arguments
guard args.count == 4, let points = Int(args[3]) else {
    FileHandle.standardError.write(Data("usage: render-icon.swift <path> <out.png> <points>\n".utf8))
    exit(1)
}
// Resolved, or a symlinked app (Safari on macOS 15) gets an alias badge.
let path = URL(fileURLWithPath: args[1]).resolvingSymlinksInPath().path
var rect = NSRect(x: 0, y: 0, width: points, height: points)
let icon = NSWorkspace.shared.icon(forFile: path)
guard let image = icon.cgImage(forProposedRect: &rect, context: nil, hints: nil),
    let png = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:])
else {
    FileHandle.standardError.write(Data("error: cannot render the icon of \(path)\n".utf8))
    exit(1)
}
try png.write(to: URL(fileURLWithPath: args[2]))
