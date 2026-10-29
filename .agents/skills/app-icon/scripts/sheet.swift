import AppKit

// Lays PNGs out in a labeled grid, each on a light or dark backdrop, as one PNG. An
// image larger than its cell shrinks to fit; a smaller one keeps its pixel size, so a
// 64 px render of a 32 pt icon is judged at the size it ships.
// usage: sheet.swift <out.png> <columns> <cell px> <label|path|light or dark>...

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data("error: \(message)\n".utf8))
    exit(1)
}

let usage = "usage: sheet.swift <out.png> <columns> <cell px> <label|path|light or dark>..."
let args = CommandLine.arguments
guard args.count > 4, let columns = Int(args[2]), let cell = Int(args[3]), columns > 0, cell > 32 else {
    fail(usage)
}
let items = args[4...].map { $0.components(separatedBy: "|") }
let labelHeight = 28
let rows = (items.count + columns - 1) / columns
let width = columns * cell
let height = rows * (cell + labelHeight)

guard
    let bitmap = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: width, pixelsHigh: height, bitsPerSample: 8,
        samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
        bytesPerRow: 0, bitsPerPixel: 0)
else { fail("cannot allocate a \(width) × \(height) sheet") }
// One point per pixel.
bitmap.size = NSSize(width: width, height: height)
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
NSColor.white.setFill()
NSRect(x: 0, y: 0, width: width, height: height).fill()

for (index, item) in items.enumerated() {
    guard item.count == 3, item[2] == "light" || item[2] == "dark" else {
        fail("bad item '\(item.joined(separator: "|"))'; \(usage)")
    }
    guard let image = NSImage(contentsOfFile: item[1]), let rep = image.representations.first,
        rep.pixelsWide > 0
    else { fail("cannot read \(item[1])") }
    let dark = item[2] == "dark"
    // AppKit's origin is the bottom left; rows run from the top.
    let x = CGFloat(index % columns * cell)
    let y = CGFloat(height - (index / columns + 1) * (cell + labelHeight))
    (dark ? NSColor(white: 0.12, alpha: 1) : NSColor(white: 0.93, alpha: 1)).setFill()
    NSRect(x: x, y: y, width: CGFloat(cell), height: CGFloat(cell + labelHeight)).insetBy(dx: 1, dy: 1).fill()

    let longest = CGFloat(max(rep.pixelsWide, rep.pixelsHigh))
    let scale = min(1, CGFloat(cell - 16) / longest)
    let size = NSSize(width: CGFloat(rep.pixelsWide) * scale, height: CGFloat(rep.pixelsHigh) * scale)
    image.draw(
        in: NSRect(
            x: x + (CGFloat(cell) - size.width) / 2, y: y + (CGFloat(cell) - size.height) / 2,
            width: size.width, height: size.height))
    item[0].draw(
        at: NSPoint(x: x + 8, y: y + CGFloat(cell) + 6),
        withAttributes: [.font: NSFont.systemFont(ofSize: 14), .foregroundColor: dark ? NSColor.white : NSColor.black])
}
NSGraphicsContext.current = nil

guard let png = bitmap.representation(using: .png, properties: [:]) else { fail("cannot encode the sheet") }
do {
    try png.write(to: URL(fileURLWithPath: args[1]))
} catch {
    fail("cannot write \(args[1]): \(error.localizedDescription)")
}
