// Renders the app icon set: a webcam on a green-room green plate. Drawn here rather than
// from SF Symbols, which Apple's license doesn't allow in app icons.
// Usage (from the repo root):
//   swiftc Scripts/render-app-icon/main.swift -o build/render-icon && build/render-icon
import AppKit

let outputDirectory = URL(filePath: "GreenRoom/Assets.xcassets/AppIcon.appiconset")

func drawWebcam(in plate: NSRect) {
    let unit = plate.width / 100
    let center = NSPoint(x: plate.midX, y: plate.minY + unit * 58)
    let white = NSColor.white

    // Stand: a neck and a wide foot.
    white.setFill()
    NSBezierPath(rect: NSRect(x: center.x - unit * 4, y: plate.minY + unit * 20, width: unit * 8, height: unit * 16)).fill()
    NSBezierPath(
        roundedRect: NSRect(x: center.x - unit * 20, y: plate.minY + unit * 16, width: unit * 40, height: unit * 8),
        xRadius: unit * 4, yRadius: unit * 4
    ).fill()

    // Body, lens ring, lens, and the glint that makes it read as glass.
    let body = NSBezierPath(ovalIn: NSRect(x: center.x - unit * 28, y: center.y - unit * 28, width: unit * 56, height: unit * 56))
    body.fill()
    NSColor(red: 0.05, green: 0.22, blue: 0.14, alpha: 1).setFill()
    NSBezierPath(ovalIn: NSRect(x: center.x - unit * 15, y: center.y - unit * 15, width: unit * 30, height: unit * 30)).fill()
    NSColor(red: 0.30, green: 0.85, blue: 0.55, alpha: 1).setFill()
    NSBezierPath(ovalIn: NSRect(x: center.x - unit * 7, y: center.y - unit * 7, width: unit * 14, height: unit * 14)).fill()
    white.withAlphaComponent(0.9).setFill()
    NSBezierPath(ovalIn: NSRect(x: center.x + unit * 2, y: center.y + unit * 2, width: unit * 4, height: unit * 4)).fill()
}

func render(_ pixels: Int) -> Data {
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels, bitsPerSample: 8, samplesPerPixel: 4,
        hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
    )!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let size = CGFloat(pixels)
    let canvas = NSRect(x: 0, y: 0, width: size, height: size)

    // macOS icon grid: the rounded square fills 824/1024 of the canvas.
    let plate = canvas.insetBy(dx: size * 100 / 1024, dy: size * 100 / 1024)
    let plateShape = NSBezierPath(roundedRect: plate, xRadius: plate.width * 0.2237, yRadius: plate.height * 0.2237)
    NSGradient(colors: [
        NSColor(red: 0.16, green: 0.62, blue: 0.38, alpha: 1),
        NSColor(red: 0.04, green: 0.30, blue: 0.18, alpha: 1)
    ])!.draw(in: plateShape, angle: -90)

    drawWebcam(in: plate)

    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

let sizes: [(points: Int, scale: Int)] = [
    (16, 1), (16, 2), (32, 1), (32, 2), (128, 1), (128, 2), (256, 1), (256, 2), (512, 1), (512, 2)
]
var images: [[String: String]] = []
for entry in sizes {
    let name = "icon_\(entry.points)x\(entry.points)@\(entry.scale)x.png"
    try! render(entry.points * entry.scale).write(to: outputDirectory.appending(path: name))
    images.append(["filename": name, "idiom": "mac", "scale": "\(entry.scale)x", "size": "\(entry.points)x\(entry.points)"])
}
let contents: [String: Any] = ["images": images, "info": ["author": "xcode", "version": 1]]
let json = try! JSONSerialization.data(withJSONObject: contents, options: [.prettyPrinted, .sortedKeys])
try! json.write(to: outputDirectory.appending(path: "Contents.json"))
print("Wrote \(images.count) icons to \(outputDirectory.path)")
