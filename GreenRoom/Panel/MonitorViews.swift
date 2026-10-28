import AppKit
import GreenRoomCore
import Observation
import SwiftUI
import UniformTypeIdentifiers

/// The record preview's tools: hands settings to the feed and its results to the views. The
/// changed picture goes straight to a layer, so 30 frames a second never re-render SwiftUI.
@MainActor
@Observable
final class PreviewMonitor {
    private(set) var scopes: LumaScopes?
    /// Whether the chosen LUT file loaded.
    private(set) var hasLUT = false
    @ObservationIgnored private(set) var settings = MonitorSettings()
    @ObservationIgnored private var feed: MonitorFeed?
    @ObservationIgnored weak var pictureLayer: CALayer?
    @ObservationIgnored private var attachedAspect: Double?
    @ObservationIgnored private var lutPath = ""
    @ObservationIgnored private var lut: PreparedLUT?

    /// Starts the camera's frames flowing to the tools, sized for the camera's aspect.
    func attach(to camera: CameraSession, aspect: Double) {
        guard attachedAspect != aspect else { return }
        attachedAspect = aspect
        let feed = feed ?? MonitorFeed(
            onPicture: Self.mainHandler { [weak self] image in self?.show(image) },
            onScopes: Self.mainHandler { [weak self] scopes in self?.show(scopes) }
        )
        self.feed = feed
        feed.settings = settings
        feed.lut = lut
        camera.attachMonitor(feed, width: 1280, aspect: aspect)
    }

    func detach(from camera: CameraSession) {
        guard attachedAspect != nil else { return }
        attachedAspect = nil
        camera.detachMonitor()
        scopes = nil
        pictureLayer?.contents = nil
    }

    func apply(_ settings: MonitorSettings, lutPath: String) {
        if lutPath != self.lutPath {
            self.lutPath = lutPath
            lut = (try? MonitorMenu.loadLUT(at: lutPath)).map(PreparedLUT.init)
            feed?.lut = lut
            hasLUT = lut != nil
        }
        var settings = settings
        settings.hasLUT = hasLUT
        self.settings = settings
        feed?.settings = settings
        if !settings.wantsScopes { scopes = nil }
        if !settings.changesPicture { pictureLayer?.contents = nil }
    }

    private func show(_ image: CGImage) {
        guard settings.changesPicture else { return }
        pictureLayer?.contents = image
    }

    private func show(_ scopes: LumaScopes) {
        guard settings.wantsScopes else { return }
        self.scopes = scopes
    }

    /// The feed calls back on its own queue, so handlers are made outside the main actor and hop back.
    nonisolated private static func mainHandler<Value: Sendable>(
        _ handle: @escaping @MainActor (Value) -> Void
    ) -> @Sendable (Value) -> Void {
        nonisolated(unsafe) let handle = handle
        return { value in DispatchQueue.main.async { MainActor.assumeIsolated { handle(value) } } }
    }
}

/// Shows the feed's changed picture, fitted like the live preview under it.
struct MonitorPicture: NSViewRepresentable {
    let monitor: PreviewMonitor

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        let layer = CALayer()
        layer.contentsGravity = .resizeAspect
        layer.actions = ["contents": NSNull()]
        view.layer = layer
        view.wantsLayer = true
        monitor.pictureLayer = layer
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}

/// Histogram and waveform, stacked. Its own view, so ten updates a second redraw just this.
struct MonitorScopes: View {
    let monitor: PreviewMonitor
    let tools: Set<MonitorTool>

    var body: some View {
        VStack(spacing: 10) {
            if tools.contains(.histogram) {
                scope("Histogram") { context, size in Self.drawHistogram(monitor.scopes, in: context, size: size) }
                    .frame(height: 80)
            }
            if tools.contains(.waveform) {
                scope("Waveform") { context, size in Self.drawWaveform(monitor.scopes, in: context, size: size) }
                    .frame(height: 110)
            }
        }
        .frame(width: 220)
        .padding(10)
        .background(.black.opacity(0.55), in: RoundedRectangle(cornerRadius: 12))
    }

    private func scope(
        _ name: String, draw: @escaping (GraphicsContext, CGSize) -> Void
    ) -> some View {
        Canvas { context, size in
            Self.drawLevels(in: context, size: size)
            draw(context, size)
        }
        .accessibilityLabel(name)
    }

    /// Faint lines at a quarter, half, and three quarters.
    static func drawLevels(in context: GraphicsContext, size: CGSize) {
        var path = Path()
        for level in [0.25, 0.5, 0.75] {
            path.move(to: CGPoint(x: 0, y: size.height * (1 - level)))
            path.addLine(to: CGPoint(x: size.width, y: size.height * (1 - level)))
        }
        context.stroke(path, with: .color(.white.opacity(0.12)), lineWidth: 1)
    }

    static func drawHistogram(_ scopes: LumaScopes?, in context: GraphicsContext, size: CGSize) {
        guard let bins = scopes?.histogram, !bins.isEmpty else { return }
        let width = size.width / CGFloat(bins.count)
        var path = Path()
        for (index, value) in bins.enumerated() {
            let height = size.height * CGFloat(value)
            path.addRect(CGRect(x: CGFloat(index) * width, y: size.height - height, width: width, height: height))
        }
        context.fill(path, with: .color(.white.opacity(0.8)))
        if let clipped = scopes?.clipped, clipped > 0.01 {
            context.fill(Path(CGRect(x: size.width - width, y: 0, width: width, height: size.height)),
                         with: .color(.red.opacity(0.8)))
        }
    }

    static func drawWaveform(_ scopes: LumaScopes?, in context: GraphicsContext, size: CGSize) {
        guard let cells = scopes?.waveform, !cells.isEmpty else { return }
        let columns = LumaScopes.waveformColumns, levels = LumaScopes.waveformLevels
        let width = size.width / CGFloat(columns), height = size.height / CGFloat(levels)
        for column in 0..<columns {
            for level in 0..<levels {
                let value = cells[column * levels + level]
                guard value > 0.02 else { continue }
                let rect = CGRect(x: CGFloat(column) * width, y: size.height - CGFloat(level + 1) * height,
                                  width: width, height: height)
                context.fill(Path(rect), with: .color(.green.opacity(Double(min(value * 1.5, 1)))))
            }
        }
    }
}

/// What each false color means.
struct FalseColorLegend: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            ForEach(FalseColor.bands.filter { $0.color != nil }, id: \.label) { band in
                HStack(spacing: 4) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Self.color(band.color))
                        .frame(width: 10, height: 10)
                    Text(band.label)
                }
            }
        }
        .font(.caption)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(.black.opacity(0.55), in: RoundedRectangle(cornerRadius: 12))
    }

    private static func color(_ rgb: FalseColor.RGB?) -> Color {
        guard let rgb else { return .gray }
        return Color(red: rgb.red, green: rgb.green, blue: rgb.blue)
    }
}

/// Turns the tools on and off. Shares its settings with the record preview through defaults.
struct MonitorMenu: View {
    static let defaultZebraPercent = 95
    @AppStorage("monitorTools") private var storedTools = ""
    @AppStorage("zebraLevel") private var zebraPercent = Self.defaultZebraPercent
    @AppStorage("peakingColor") private var peakingColor = PeakingColor.red
    @AppStorage("peakingSensitivity") private var peakingSensitivity = PeakingSensitivity.medium
    @AppStorage("previewLUT") private var lutPath = ""

    var body: some View {
        let tools = MonitorTool.decode(storedTools)
        Menu {
            Section("Scopes") {
                toggle(.histogram, in: tools)
                toggle(.waveform, in: tools)
            }
            Section("Picture") {
                toggle(.zebras, in: tools)
                toggle(.falseColor, in: tools)
                toggle(.peaking, in: tools)
                toggle(.monochrome, in: tools)
            }
            Section("LUT") {
                toggle(.lut, in: tools)
                    .disabled(lutPath.isEmpty)
                Button(lutPath.isEmpty ? "Load LUT…" : "LUT: \(lutName)…") { chooseLUT(tools: tools) }
            }
            Divider()
            Picker("Zebra Level", selection: $zebraPercent) {
                ForEach([70, 80, 90, 95, 100], id: \.self) { Text("\($0)%").tag($0) }
            }
            Picker("Peaking Color", selection: $peakingColor) {
                ForEach(PeakingColor.allCases) { Text($0.title).tag($0) }
            }
            Picker("Peaking Sensitivity", selection: $peakingSensitivity) {
                ForEach(PeakingSensitivity.allCases) { Text($0.title).tag($0) }
            }
        } label: {
            Image(systemName: "camera.aperture")
        }
        .menuIndicator(.hidden)
        .fixedSize()
        .help("Scopes, zebras, false color, and focus peaking. They aren't recorded.")
        .accessibilityLabel("Monitor tools")
    }

    private var lutName: String {
        URL(fileURLWithPath: lutPath).deletingPathExtension().lastPathComponent
    }

    static func loadLUT(at path: String) throws -> CubeLUT {
        try CubeLUT(parsing: String(contentsOf: URL(fileURLWithPath: path), encoding: .utf8))
    }

    /// Checks the file reads before keeping it, and turns the preview on.
    private func chooseLUT(tools: Set<MonitorTool>) {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [UTType(filenameExtension: "cube") ?? .data]
        panel.message = "Choose a 3D LUT (.cube), such as your camera maker's log to Rec. 709"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            _ = try Self.loadLUT(at: url.path)
            lutPath = url.path
            storedTools = MonitorTool.encode(tools.union([.lut]))
        } catch {
            let alert = NSAlert()
            alert.messageText = "Green Room can't use that LUT"
            alert.informativeText = "It needs to be a 3D .cube file with a 0 to 1 input range."
            alert.runModal()
        }
    }

    private func toggle(_ tool: MonitorTool, in tools: Set<MonitorTool>) -> some View {
        Toggle(tool.title, isOn: Binding(
            get: { tools.contains(tool) },
            set: { on in
                var next = tools
                if on { next.insert(tool) } else { next.remove(tool) }
                storedTools = MonitorTool.encode(next)
            }
        ))
        .help(tool.help)
    }
}
