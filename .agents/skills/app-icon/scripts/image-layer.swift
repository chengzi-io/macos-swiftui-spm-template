import AppKit
import CoreImage
import Vision

// Turns an image (a logo export, an image-model result) into a 1024 × 1024 icon layer:
// trimmed to its visible pixels, scaled to fit a <size> square and centered on (<x>, <y>),
// in canvas points with y down, as in SVG. An image with no transparency first has its
// subject cut out by Vision, which also drops enclosed areas that match the background
// (a white window in a logo on white): look at the result.
// usage: image-layer.swift <image> <out.png> [size=640] [x=512] [y=512]

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data("error: \(message)\n".utf8))
    exit(1)
}

let usage = "usage: image-layer.swift <image> <out.png> [size=640] [x=512] [y=512]"
let args = CommandLine.arguments
guard (3...6).contains(args.count) else { fail(usage) }
let numbers = args.dropFirst(3).compactMap(Double.init)
guard numbers.count == args.count - 3 else { fail(usage) }
let (input, output) = (args[1], args[2])
let size = numbers.count > 0 ? numbers[0] : 640
let center = CGPoint(x: numbers.count > 1 ? numbers[1] : 512, y: numbers.count > 2 ? numbers[2] : 512)
let canvas = 1024
let sRGB = CGColorSpace(name: CGColorSpace.sRGB)!

func bitmap(_ width: Int, _ height: Int) -> CGContext {
    guard
        let context = CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
            space: sRGB, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
    else { fail("cannot allocate \(width) × \(height) pixels") }
    return context
}

/// The box around pixels that are more than faintly visible, in image coordinates (top
/// left origin, as `cropping(to:)` takes), and whether any pixel is see-through at all.
func visibleBox(_ image: CGImage) -> (box: CGRect?, transparent: Bool) {
    let (width, height) = (image.width, image.height)
    let context = bitmap(width, height)
    context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
    let pixels = context.data!.assumingMemoryBound(to: UInt8.self)
    var (minX, minY, maxX, maxY) = (width, height, -1, -1)
    var transparent = false
    // Rows in memory run from the top of the image.
    for row in 0..<height {
        for column in 0..<width {
            let alpha = pixels[(row * width + column) * 4 + 3]
            if alpha < 255 { transparent = true }
            if alpha > 8 {
                minX = min(minX, column)
                maxX = max(maxX, column)
                minY = min(minY, row)
                maxY = max(maxY, row)
            }
        }
    }
    guard maxX >= 0 else { return (nil, transparent) }
    return (CGRect(x: minX, y: minY, width: maxX - minX + 1, height: maxY - minY + 1), transparent)
}

func liftSubject(_ image: CGImage) -> CGImage {
    let request = VNGenerateForegroundInstanceMaskRequest()
    let handler = VNImageRequestHandler(cgImage: image)
    do {
        try handler.perform([request])
    } catch {
        fail("Vision cannot read \(input): \(error.localizedDescription)")
    }
    guard let result = request.results?.first, !result.allInstances.isEmpty else {
        fail("Vision found no subject in \(input); export it with a transparent background")
    }
    let masked: CVPixelBuffer
    do {
        masked = try result.generateMaskedImage(
            ofInstances: result.allInstances, from: handler, croppedToInstancesExtent: false)
    } catch {
        fail("Vision cannot cut out the subject of \(input): \(error.localizedDescription)")
    }
    let lifted = CIImage(cvPixelBuffer: masked)
    guard let image = CIContext().createCGImage(lifted, from: lifted.extent, format: .RGBA8, colorSpace: sRGB) else {
        fail("cannot render the subject of \(input)")
    }
    return image
}

guard let loaded = NSImage(contentsOfFile: input)?.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
    fail("cannot read \(input)")
}
var image = loaded
var (box, transparent) = visibleBox(image)
if !transparent {
    FileHandle.standardError.write(
        Data("note: \(input) has no transparency; cut out its subject with Vision\n".utf8))
    image = liftSubject(image)
    (box, _) = visibleBox(image)
}
guard let box, let content = image.cropping(to: box) else { fail("\(input) has nothing visible") }

let scale = size / Double(max(box.width, box.height))
if scale > 1 {
    FileHandle.standardError.write(
        Data("note: \(input) is enlarged \(String(format: "%.1f", scale))×; a larger source stays sharper\n".utf8))
}
let (width, height) = (Double(box.width) * scale, Double(box.height) * scale)
let context = bitmap(canvas, canvas)
context.interpolationQuality = .high
// The context's origin is the bottom left.
context.draw(
    content,
    in: CGRect(x: center.x - width / 2, y: Double(canvas) - center.y - height / 2, width: width, height: height))
guard let layer = context.makeImage(),
    let png = NSBitmapImageRep(cgImage: layer).representation(using: .png, properties: [:])
else { fail("cannot encode \(output)") }
do {
    try png.write(to: URL(fileURLWithPath: output))
} catch {
    fail("cannot write \(output): \(error.localizedDescription)")
}
print(output)
