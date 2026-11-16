#if DEBUG
import AppKit
import GreenRoomCore
import PanelKit
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
        for dark in [false, true] {
            render(ProblemSample(), dark: dark, to: "\(folder)/problem-\(dark ? "dark" : "light").png")
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
/// The panel's warning states with made-up devices: two issues, a headset in call mode, the
/// mic comparison, a missing and a flaky device, and a failing recording check.
private struct ProblemSample: View {
    private let display = Device(id: "display", name: "Studio Display", kind: .speaker, transport: .display)
    private let pods = Device(id: "pods", name: "AirPods Pro", kind: .speaker, transport: .bluetooth)
    private let podsMic = Device(id: "pods-mic", name: "AirPods Pro", kind: .microphone, transport: .bluetooth)
    private let shure = Device(id: "shure", name: "Shure MV7", kind: .microphone, transport: .usb)
    private let mac = Device(id: "mac", name: "MacBook Pro Microphone", kind: .microphone, transport: .builtIn)

    var body: some View {
        let snapshot = Snapshot(
            devices: [.speaker: [display, pods], .microphone: [shure, podsMic, mac]],
            active: [.speaker: pods, .microphone: shure],
            live: [LiveUse(kind: .speaker, deviceID: "pods", app: "Zoom"),
                   LiveUse(kind: .microphone, deviceID: "pods-mic", app: "Zoom")],
            sampleRates: ["pods-mic": 16_000]
        )
        let check = ReadyCheck(
            readiness: .notReady([
                Mismatch(kind: .speaker, expected: display, problem: .notSelected(actual: pods), fix: display),
                Mismatch(kind: .microphone, expected: shure, problem: .appUsing(app: "Zoom", actual: podsMic))
            ]),
            advisories: Advisory.evaluate(snapshot)
        )
        Panel(accent: PanelAccent.greenRoom) {
            Fascia(nameplate: "Frame", timestamp: "Studio setup", label: "Cam Link 4K · USB") {
                VStack(spacing: 8) {
                    ChromeBezel {
                        LinearGradient(colors: [.gray, .black], startPoint: .top, endPoint: .bottom)
                            .overlay(alignment: .topLeading) { TallyLight("Live").padding(7) }
                    }
                    TipStrip("Your face is dark. Add a light in front of you.", accessibilityPrefix: "Framing tip")
                }
            }
            StatusVerdict(check: check, setupName: "Studio", proposed: Setup(name: "", devices: [:]),
                          select: { _ in }, ignore: { _ in })
            ForEach(check.advisories, id: \.device.id) { AdvisoryCard(advisory: $0) { _ in } }
            SectionHeader("Speaker")
            VStack(alignment: .leading, spacing: 4) {
                LiveCaption(kind: .speaker, snapshot: snapshot, selected: display) { _ in }
                MicComparison(mics: [shure, mac, podsMic], active: shure,
                              levels: ["shure": 0.95, "mac": 0.24]) { _ in }
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 8)
            PanelNote(text: MicProblem.silent.message, caution: true)
            SectionHeader("Usually here, missing now")
            MissingRow(missing: MissingDevice(
                device: Device(id: "atr", name: "ATR2100x-USB Microphone", kind: .microphone, transport: .usb),
                lastSeen: .now.addingTimeInterval(-86_400), reason: .notOnUSB
            ))
            SectionHeader("Keeps disconnecting")
            FlakyRow(message: "Cam Link 4K dropped out and came back 3 times this week",
                     advice: "Try another cable or port, or plug it straight into your Mac instead of a hub.")
            Disclosure("Ready to record?", initiallyExpanded: true) {
                ForEach(Self.items, id: \.title) { RecordingCheckRow(item: $0) }
            }
            .overlay(alignment: .top) { PanelHairline() }
        } footer: {
            HStack(spacing: 6) {
                Menu {
                    Button("Studio") {}
                } label: {
                    HStack(spacing: 4) {
                        Text("Studio")
                        Image(systemName: "chevron.down").font(.system(size: 8, weight: .bold))
                    }
                }
                .menuStyle(.button)
                .buttonStyle(.panelCompact)
                .menuIndicator(.hidden)
                .fixedSize()
                Button("History") {}.buttonStyle(.panelCompact)
                Spacer()
            }
            .padding(.vertical, 9)
            .padding(.horizontal, 14)
            .overlay(alignment: .top) { PanelHairline() }
        }
    }

    private static let items: [RecordingCheck.Item] = {
        let json = """
        [{"title": "Microphone", "detail": "AirPods Pro · 24 kHz, phone quality. Use a wired mic.", "passed": false},
         {"title": "Power", "detail": "On battery. Plug in so the Mac doesn't slow down.", "passed": false},
         {"title": "Disk space", "detail": "212 GB free", "passed": true}]
        """
        return (try? JSONDecoder().decode([RecordingCheck.Item].self, from: Data(json.utf8))) ?? []
    }()
}
#endif
