#if DEBUG
import AppKit
import SwiftUI

/// `--render-panel <folder>`: draws the panel in light and dark, with "Ready to record?" open,
/// and the menu bar icon's states, then quits. For before-and-after screenshots without
/// clicking the menu bar. The camera preview draws black here.
@MainActor
enum PanelSample {
    static func write(to folder: String, monitor: DeviceMonitor, checks: Checks, updater: Updater) {
        let defaults = UserDefaults.standard
        let wasExpanded = defaults.object(forKey: "showRecordingCheck")
        for expanded in [false, true] {
            defaults.set(expanded, forKey: "showRecordingCheck")
            for dark in [false, true] {
                let panel = PanelView(
                    monitor: monitor, checks: checks, updater: updater, fit: PanelFit(),
                    showHistory: {}, closePanel: {}, showRecordPreview: {}, showSettings: {}
                )
                let name = "panel-\(dark ? "dark" : "light")\(expanded ? "-expanded" : "").png"
                render(panel, dark: dark, to: "\(folder)/\(name)")
            }
        }
        if let wasExpanded { defaults.set(wasExpanded, forKey: "showRecordingCheck") } else {
            defaults.removeObject(forKey: "showRecordingCheck")
        }
        writeGlyphs(to: "\(folder)/menubar.png")
    }

    static func render<Content: View>(_ view: Content, dark: Bool, to path: String) {
        let hosting = NSHostingView(rootView: view)
        hosting.appearance = NSAppearance(named: dark ? .darkAqua : .aqua)
        let window = NSWindow(contentRect: .zero, styleMask: .borderless, backing: .buffered, defer: false)
        window.appearance = hosting.appearance
        window.contentView = hosting
        hosting.layoutSubtreeIfNeeded()
        let size = hosting.fittingSize
        window.setContentSize(size)
        hosting.frame = NSRect(origin: .zero, size: size)
        hosting.layoutSubtreeIfNeeded()
        let background = dark ? NSColor(white: 0.16, alpha: 1) : NSColor(white: 0.93, alpha: 1)
        hosting.layer?.backgroundColor = background.cgColor
        guard let rep = hosting.bitmapImageRepForCachingDisplay(in: hosting.bounds) else { return }
        hosting.cacheDisplay(in: hosting.bounds, to: rep)
        try? rep.representation(using: .png, properties: [:])?.write(to: URL(fileURLWithPath: path))
    }

    /// Each menu bar state on a light and a dark strip, at 2x.
    private static func writeGlyphs(to path: String) {
        let images = StatusGlyph.allCases.map(\.image)
        let cell = 30.0, height = 24.0
        let size = NSSize(width: cell * Double(images.count), height: height * 2)
        let image = NSImage(size: size, flipped: false) { _ in
            for (row, dark) in [true, false].enumerated() {
                let y = Double(row) * height
                (dark ? NSColor(white: 0.12, alpha: 1) : NSColor(white: 0.9, alpha: 1)).setFill()
                NSRect(x: 0, y: y, width: size.width, height: height).fill()
                for (index, glyph) in images.enumerated() {
                    let rect = NSRect(x: Double(index) * cell + (cell - 18) / 2, y: y + (height - 18) / 2,
                                      width: 18, height: 18)
                    let tinted = NSImage(size: rect.size, flipped: false) { bounds in
                        glyph.draw(in: bounds)
                        (dark ? NSColor.white : NSColor.black).set()
                        bounds.fill(using: .sourceAtop)
                        return true
                    }
                    tinted.draw(in: rect)
                }
            }
            return true
        }
        let scaled = NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: Int(size.width * 2), pixelsHigh: Int(size.height * 2),
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
            colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
        )
        guard let scaled else { return }
        scaled.size = size
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: scaled)
        image.draw(in: NSRect(origin: .zero, size: size))
        NSGraphicsContext.restoreGraphicsState()
        try? scaled.representation(using: .png, properties: [:])?.write(to: URL(fileURLWithPath: path))
    }
}
#endif
