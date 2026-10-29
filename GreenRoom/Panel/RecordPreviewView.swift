import AVFoundation
import GreenRoomCore
import SwiftUI

/// The camera as big as the screen, to check a shot before recording. Shows the whole frame,
/// so nothing at the edges is a surprise. The controls fade when the mouse is still, so a
/// teleprompter shows just the picture and the mic level.
struct RecordPreviewView: View {
    let monitor: DeviceMonitor
    let checks: Checks
    let close: () -> Void
    @State private var controlsShown = true
    @State private var overControls = false
    @State private var showingCheck = false
    @State private var showingGuides = false
    @State private var showingMonitor = false
    @State private var hideTask: Task<Void, Never>?
    @AppStorage("previewGuides") private var storedGuides = ""
    @AppStorage("previewTurns") private var turns = 0
    @AppStorage("previewMirrored") private var mirrored = true
    @AppStorage("monitorTools") private var storedTools = ""
    @AppStorage("zebraLevel") private var zebraPercent = MonitorMenu.defaultZebraPercent
    @AppStorage("peakingColor") private var peakingColor = PeakingColor.red
    @AppStorage("peakingSensitivity") private var peakingSensitivity = PeakingSensitivity.medium
    @AppStorage("previewLUT") private var lutPath = ""
    @State private var monitorTools = PreviewMonitor()

    var body: some View {
        ZStack {
            Color.black
            if checks.cameraAccess == .authorized, monitor.previewCamera != nil {
                CameraPreview(session: checks.camera.session, gravity: .resizeAspect, orientation: orientation)
                if monitorSettings.changesPicture {
                    MonitorPicture(monitor: monitorTools)
                }
                CompositionOverlay(guides: CompositionGuide.decode(storedGuides), aspect: frameAspect)
            } else {
                Text(cameraMessage).font(.title3).foregroundStyle(.secondary)
            }
            VStack {
                HStack(alignment: .top) {
                    readinessPill
                    Spacer()
                    if let advice = checks.camera.advice {
                        Label(advice, systemImage: "lightbulb").pill()
                    }
                }
                Spacer()
                controls
                    .onHover { overControls = $0 }
            }
            .padding(20)
            .opacity(controlsShown ? 1 : 0)
            .allowsHitTesting(controlsShown)
            PreviewMicMeter(meter: checks.meter)
            monitorColumn
        }
        .frame(minWidth: 720, minHeight: 480)
        .environment(\.colorScheme, .dark)
        .onContinuousHover { _ in showControls() }
        .onAppear {
            showControls()
            #if DEBUG
            showingGuides = CommandLine.arguments.contains("--open-guides-popover")
            showingMonitor = CommandLine.arguments.contains("--open-monitor-popover")
            #endif
            syncMonitor()
            checks.camera.setOrientation(orientation)
        }
        .onDisappear {
            hideTask?.cancel()
            monitorTools.detach(from: checks.camera)
            checks.camera.setOrientation(PictureOrientation())
        }
        .onChange(of: orientation) { checks.camera.setOrientation(orientation) }
        .onChange(of: monitor.previewCamera) {
            checks.restartCamera()
            syncMonitor()
        }
        .onChange(of: monitorSettings) { syncMonitor() }
        .onChange(of: checks.cameraAccess) { syncMonitor() }
        .onChange(of: lutPath) { syncMonitor() }
        .onChange(of: monitor.snapshot.active(.microphone)) { checks.restartMeter() }
    }

    private var monitorSettings: MonitorSettings {
        MonitorSettings(
            tools: MonitorTool.decode(storedTools),
            zebraLevel: zebraPercent >= 100 ? 0.99 : Double(zebraPercent) / 100,
            peakingColor: peakingColor, peakingSensitivity: peakingSensitivity, orientation: orientation,
            hasLUT: monitorTools.hasLUT
        )
    }

    /// Frames only go to the tools while one is on, so a plain preview costs nothing extra.
    private func syncMonitor() {
        let settings = monitorSettings
        monitorTools.apply(settings, lutPath: lutPath)
        if settings.tools.isEmpty || monitor.previewCamera == nil || checks.cameraAccess != .authorized {
            monitorTools.detach(from: checks.camera)
        } else {
            monitorTools.attach(to: checks.camera, aspect: Double(cameraAspect))
        }
    }

    /// Scopes and the false color key, on the right. Like the mic meter, they stay up when
    /// the controls fade.
    private var monitorColumn: some View {
        let tools = MonitorTool.decode(storedTools)
        return HStack {
            Spacer()
            VStack(spacing: 10) {
                if tools.contains(.histogram) || tools.contains(.waveform) {
                    MonitorScopes(monitor: monitorTools, tools: tools)
                }
                if tools.contains(.falseColor) {
                    FalseColorLegend().frame(width: 240)
                }
            }
        }
        .padding(.trailing, 20)
        .allowsHitTesting(false)
    }

    private var orientation: PictureOrientation {
        PictureOrientation(quarterTurns: turns, mirrored: mirrored)
    }

    /// Width over height of the picture as shown, so the guides line up with it.
    private var frameAspect: CGFloat {
        CGFloat(orientation.displayAspect(Double(cameraAspect)))
    }

    /// Width over height of what the camera sends.
    private var cameraAspect: CGFloat {
        guard let capture = monitor.previewCamera.flatMap(Cameras.captureDevice(for:)) else { return 16.0 / 9.0 }
        let size = CMVideoFormatDescriptionGetDimensions(capture.activeFormat.formatDescription)
        return size.height > 0 ? CGFloat(size.width) / CGFloat(size.height) : 16.0 / 9.0
    }

    /// For a camera mounted sideways or upside down. Only the preview turns, not the recording.
    private var turnMenu: some View {
        Menu {
            Button("Rotate Right") { turns = (turns + 1) % 4 }
            Button("Rotate Left") { turns = (turns + 3) % 4 }
            Button("Upright") { turns = 0 }
                .disabled(turns == 0)
            Divider()
            Toggle("Mirror", isOn: $mirrored)
                .help("Show the picture flipped, like a mirror. Recordings aren't flipped.")
        } label: {
            Image(systemName: "rotate.right")
        }
        .menuIndicator(.hidden)
        .fixedSize()
        .help("Turn or mirror the picture, for a camera mounted sideways or upside down")
        .accessibilityLabel("Rotate")
    }

    /// A popover rather than a menu, so several guides can be switched without reopening it.
    private var guidesMenu: some View {
        let guides = CompositionGuide.decode(storedGuides)
        return Button { showingGuides.toggle() } label: {
            Image(systemName: "squareshape.split.3x3")
        }
        .help("Grid lines and crop guides over the picture. They aren't recorded.")
        .accessibilityLabel("Guides")
        .popover(isPresented: $showingGuides, arrowEdge: .top) {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(CompositionGuide.allCases) { guide in
                    Toggle(guide.title, isOn: Binding(
                        get: { guides.contains(guide) },
                        set: { on in
                            var next = guides
                            if on { next.insert(guide) } else { next.remove(guide) }
                            storedGuides = CompositionGuide.encode(next)
                        }
                    ))
                    ToolExplainer(text: guide.help)
                }
            }
            .toggleStyle(.checkbox)
            .padding(14)
            .frame(width: 300)
        }
    }

    private var cameraMessage: String {
        if monitor.snapshot.devices(.camera).isEmpty { return "No camera connected" }
        return switch checks.cameraAccess {
        case .denied, .restricted: "Allow camera access in System Settings › Privacy & Security"
        default: "Starting camera…"
        }
    }

    /// Brings the controls back, then fades them after three still seconds.
    private func showControls() {
        withAnimation(.easeOut(duration: 0.15)) { controlsShown = true }
        hideTask?.cancel()
        hideTask = Task {
            try? await Task.sleep(for: .seconds(3))
            guard !Task.isCancelled, !overControls, !showingCheck, !showingGuides, !showingMonitor else { return }
            withAnimation(.easeIn(duration: 0.4)) { controlsShown = false }
            NSCursor.setHiddenUntilMouseMoves(true)
        }
    }

    private var readinessPill: some View {
        let check = monitor.recordingCheck
        let problems = check.items.filter { !$0.passed }.count
        return Button { showingCheck.toggle() } label: {
            Label {
                Text(problems == 0 ? "Ready to record" : "\(problems) to check before recording")
            } icon: {
                Image(systemName: problems == 0 ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                    .foregroundStyle(problems == 0 ? .green : .orange)
            }
            .pill()
        }
        .buttonStyle(.plain)
        .popover(isPresented: $showingCheck, arrowEdge: .bottom) {
            VStack(alignment: .leading, spacing: 10) {
                RecordingChecklist(check: check)
            }
            .padding(16)
            .frame(width: 320, alignment: .leading)
        }
    }

    /// One row. On a narrow screen like a teleprompter, long device names shorten first.
    private var controls: some View {
        ViewThatFits(in: .horizontal) {
            controlRow(menuWidth: nil)
            controlRow(menuWidth: 150)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.regularMaterial, in: Capsule())
    }

    private func controlRow(menuWidth: CGFloat?) -> some View {
        HStack(spacing: 14) {
            device(.camera, symbol: "video.fill", selected: monitor.previewCamera, width: menuWidth)
            Divider().frame(height: 20)
            device(.microphone, symbol: "mic.fill", selected: monitor.snapshot.active(.microphone), width: menuWidth)
            Button(checks.playback.buttonTitle) { checks.hearYourself() }
                .disabled(checks.micAccess != .authorized || checks.playback.phase != .idle)
                .help("Records five seconds and plays them back. Nothing is saved.")
            Divider().frame(height: 20)
            device(.speaker, symbol: "speaker.wave.2.fill", selected: monitor.snapshot.active(.speaker),
                   width: menuWidth)
            Button(checks.tone.buttonTitle) { checks.tone.play() }
                .disabled(checks.tone.playing != nil)
            Divider().frame(height: 20)
            guidesMenu
            turnMenu
            MonitorMenu(isPresented: $showingMonitor)
            Divider().frame(height: 20)
            Button("Done", action: close)
                .keyboardShortcut(.cancelAction)
                .help("Close the preview (Esc)")
        }
        .fixedSize()
    }

    private func device(_ kind: DeviceKind, symbol: String, selected: Device?, width: CGFloat?) -> some View {
        HStack(spacing: 6) {
            Image(systemName: symbol).foregroundStyle(.secondary).accessibilityHidden(true)
            if let width {
                DeviceMenu(kind: kind, monitor: monitor, selected: selected, showsTransport: false)
                    .frame(width: width)
            } else {
                DeviceMenu(kind: kind, monitor: monitor, selected: selected, showsTransport: false)
                    .fixedSize()
            }
        }
    }
}

/// Stays up when the controls fade, so you can watch your level while you talk. Its own view,
/// so the level's 15 updates a second redraw just the meter.
struct PreviewMicMeter: View {
    let meter: MicMeter

    var body: some View {
        HStack {
            VStack(spacing: 8) {
                SegmentedLevelMeter(level: meter.level)
                Image(systemName: "mic.fill").font(.caption).foregroundStyle(.secondary)
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 8)
            .background(.black.opacity(0.45), in: Capsule())
            Spacer()
        }
        .padding(.leading, 20)
    }
}

/// A tall meter in steps: green for talking, yellow when loud, red near clipping.
struct SegmentedLevelMeter: View {
    let level: Float
    private let segments = 24

    var body: some View {
        VStack(spacing: 3) {
            ForEach((0..<segments).reversed(), id: \.self) { index in
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(color(index).opacity(Float(index) < level * Float(segments) ? 1 : 0.18))
                    .frame(width: 10, height: 6)
            }
        }
        .animation(.linear(duration: 0.08), value: level)
        .accessibilityElement()
        .accessibilityLabel("Microphone level")
        .accessibilityValue("\(Int(level * 100)) percent")
    }

    private func color(_ index: Int) -> Color {
        let position = Double(index) / Double(segments)
        if position >= 0.9 { return .red }
        if position >= 0.7 { return .yellow }
        return .green
    }
}

private extension View {
    func pill() -> some View {
        font(.callout)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(.regularMaterial, in: Capsule())
    }
}
