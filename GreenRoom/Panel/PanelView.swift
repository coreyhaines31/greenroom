import AVFoundation
import GreenRoomCore
import SwiftUI

/// How tall the panel may get: the room below the menu bar on the screen it opens on.
@MainActor
@Observable
final class PanelFit {
    var maxHeight: CGFloat = .infinity
}

struct PanelView: View {
    let monitor: DeviceMonitor
    let checks: Checks
    let updater: Updater
    let fit: PanelFit
    let showHistory: () -> Void
    let closePanel: () -> Void
    let showSettings: () -> Void
    @State private var contentHeight: CGFloat?

    /// Scrolls only when the screen is too short for everything, like a teleprompter display.
    var body: some View {
        ScrollView {
            content
                .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { contentHeight = $0 }
        }
        .scrollBounceBehavior(.basedOnSize)
        .frame(width: 340, height: contentHeight.map { min($0, fit.maxHeight) })
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 14) {
            StatusHeader(monitor: monitor)
            ForEach(monitor.advisories, id: \.device.id) { advisory in
                AdvisoryCard(advisory: advisory) { monitor.select($0) }
            }
            cameraSection
            microphoneSection
            speakerSection
            if !monitor.missing.isEmpty {
                missingSection
            }
            if !monitor.flaky.isEmpty {
                flakySection
            }
            RecordingSection(monitor: monitor)
            Divider()
            footer
        }
        .padding(16)
        .frame(width: 340)
        .onChange(of: monitor.previewCamera) { checks.restartCamera() }
        .onChange(of: monitor.snapshot.active(.microphone)) { checks.restartMeter() }
        .onChange(of: monitor.snapshot.devices(.microphone)) { checks.restartCompare() }
    }

    private var cameraSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            DevicePicker(kind: .camera, monitor: monitor, selected: monitor.previewCamera)
            ZStack {
                RoundedRectangle(cornerRadius: 8).fill(.black)
                if checks.cameraAccess == .authorized, monitor.previewCamera != nil {
                    CameraPreview(session: checks.camera.session)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                } else {
                    Text(cameraMessage).font(.callout).foregroundStyle(.secondary).padding()
                }
            }
            // 16:9 at the panel's 308pt content width.
            .frame(maxWidth: .infinity)
            .frame(height: 173)
            if let advice = checks.camera.advice {
                Label(advice, systemImage: "lightbulb")
                    .font(.caption).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var cameraMessage: String {
        if monitor.snapshot.devices(.camera).isEmpty { return "No camera connected" }
        return switch checks.cameraAccess {
        case .denied, .restricted: "Allow camera access in System Settings › Privacy & Security"
        default: "Starting camera…"
        }
    }

    private var microphoneSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            DevicePicker(kind: .microphone, monitor: monitor, selected: monitor.snapshot.active(.microphone)) {
                if checks.micAccess == .authorized, monitor.snapshot.devices(.microphone).count > 1 {
                    Button(checks.inputs.isOn ? "Done" : "Compare") { checks.toggleCompare() }
                        .fixedSize()
                        .help("Shows a live level for every mic, so you can see which one hears you")
                }
            }
            if checks.inputs.isOn {
                MicComparison(mics: checks.comparableMics, active: monitor.snapshot.active(.microphone),
                              levels: checks.inputs.levels) { monitor.select($0) }
            }
            if checks.micAccess == .denied || checks.micAccess == .restricted {
                Text("Allow microphone access in System Settings › Privacy & Security")
                    .font(.caption).foregroundStyle(.secondary)
            } else {
                HStack(spacing: 10) {
                    LevelMeter(level: checks.meter.level)
                    Button(checks.playback.buttonTitle) { checks.hearYourself() }
                        .controlSize(.small)
                        .fixedSize()
                        .disabled(checks.playback.phase != .idle)
                        .help("Records five seconds and plays them back, so you hear what others will. "
                            + "Nothing is saved.")
                }
                if let problem = monitor.micProblem ?? (checks.meter.isSilent ? .silent : nil) {
                    Label(problem.message, systemImage: "exclamationmark.triangle.fill")
                        .font(.caption).foregroundStyle(.orange)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private var flakySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Keeps disconnecting").font(.caption).foregroundStyle(.secondary)
            ForEach(monitor.flaky, id: \.device.id) { flaky in
                VStack(alignment: .leading, spacing: 2) {
                    Text(flaky.message).font(.callout.weight(.medium))
                    Text(flaky.advice).font(.caption).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private var missingSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Usually here, missing now").font(.caption).foregroundStyle(.secondary)
            ForEach(monitor.missing) { missing in
                MissingRow(missing: missing)
            }
        }
    }

    private var speakerSection: some View {
        DevicePicker(kind: .speaker, monitor: monitor, selected: monitor.snapshot.active(.speaker)) {
            Button(checks.tone.buttonTitle) { checks.tone.play() }
                .disabled(checks.tone.playing != nil)
        }
    }

    private var footer: some View {
        HStack {
            if monitor.setups.isEmpty {
                Button("Save as my setup") { monitor.saveSetup() }
                    .help("Remember these devices and warn when something's different")
            } else {
                SetupMenu(monitor: monitor, closePanel: closePanel)
            }
            Button("History") { showHistory() }
            Spacer()
            OptionsMenu(updater: updater, showSettings: showSettings)
        }
    }
}

/// Settings, updates, and quit. The toggles live in the Settings window.
struct OptionsMenu: View {
    let updater: Updater
    let showSettings: () -> Void

    var body: some View {
        Menu {
            Button("Settings…", action: showSettings)
                .keyboardShortcut(",")
            Button("Check for Updates…") { updater.checkForUpdates() }
            Divider()
            Button("Quit Green Room") { NSApp.terminate(nil) }
        } label: {
            Image(systemName: "gearshape")
        }
        .menuIndicator(.hidden)
        .fixedSize()
        .accessibilityLabel("Options")
    }
}

struct MissingRow: View {
    let missing: MissingDevice

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(missing.device.name).font(.callout.weight(.medium))
            Text(summary).font(.caption).foregroundStyle(.orange)
            Text(missing.reason.advice).font(.caption).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var summary: String {
        guard let lastSeen = missing.lastSeen else { return missing.reason.headline }
        return "\(missing.reason.headline) · last seen \(LastSeen.text(lastSeen))"
    }
}

enum LastSeen {
    static func text(_ date: Date, now: Date = .now) -> String {
        let calendar = Calendar.current
        let time = date.formatted(date: .omitted, time: .shortened)
        if calendar.isDateInToday(date) { return "today \(time)" }
        if calendar.isDateInYesterday(date) { return "yesterday \(time)" }
        return date.formatted(.dateTime.weekday(.wide).month().day())
    }
}

struct DevicePicker<Trailing: View>: View {
    let kind: DeviceKind
    let monitor: DeviceMonitor
    let selected: Device?
    /// Sits on the picker's line, like the speaker's Test button.
    @ViewBuilder var trailing: Trailing

    init(kind: DeviceKind, monitor: DeviceMonitor, selected: Device?, @ViewBuilder trailing: () -> Trailing) {
        self.kind = kind
        self.monitor = monitor
        self.selected = selected
        self.trailing = trailing()
    }

    var body: some View {
        // A hidden device still shows while it's the one in use.
        let devices = monitor.snapshot.devices(kind).filter { !monitor.names.isHidden($0) || $0.id == selected?.id }
        VStack(alignment: .leading, spacing: 4) {
            Text(kind.title).font(.caption).foregroundStyle(.secondary)
            HStack {
                picker(devices)
                Spacer(minLength: 8)
                trailing
            }
            LiveCaption(kind: kind, snapshot: monitor.snapshot, selected: selected)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func picker(_ devices: [Device]) -> some View {
        Picker(kind.title, selection: Binding(
            get: { selected?.id ?? "" },
            set: { id in devices.first { $0.id == id }.map { monitor.select($0) } }
        )) {
            if selected == nil { Text("None").tag("") }
            ForEach(devices) { device in
                Text("\(device.name) · \(device.transport.label)").tag(device.id)
            }
        }
        .labelsHidden()
        .fixedSize()
    }
}

extension DevicePicker where Trailing == EmptyView {
    init(kind: DeviceKind, monitor: DeviceMonitor, selected: Device?) {
        self.init(kind: kind, monitor: monitor, selected: selected) { EmptyView() }
    }
}

/// Every mic with its own live level. Click one to use it.
struct MicComparison: View {
    let mics: [Device]
    let active: Device?
    let levels: [String: Float]
    let select: (Device) -> Void

    var body: some View {
        VStack(spacing: 0) {
            ForEach(mics) { device in
                Button { select(device) } label: { row(device) }
                    .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 8))
    }

    private func row(_ device: Device) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tint)
                .opacity(device.id == active?.id ? 1 : 0)
            Text(device.name).lineLimit(1).truncationMode(.tail)
            Spacer(minLength: 8)
            if InputMeters.canMeter(device) {
                LevelMeter(level: levels[device.id] ?? 0).frame(width: 72)
            } else if device.id != active?.id {
                Text("Switch to test").font(.caption).foregroundStyle(.secondary)
                    .help(device.transport == .bluetooth
                        ? "Opening a headset's mic drops it to call quality, so it's only tested once you use it."
                        : "Opening the iPhone mic wakes your phone, so it's only tested once you use it.")
            }
        }
        .font(.callout)
        .padding(.vertical, 5)
        .contentShape(Rectangle())
    }
}

struct LevelMeter: View {
    let level: Float

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(.quaternary)
                Capsule().fill(color).frame(width: proxy.size.width * CGFloat(level))
            }
        }
        .frame(height: 6)
        .animation(.linear(duration: 0.08), value: level)
        .accessibilityLabel("Microphone level")
        .accessibilityValue("\(Int(level * 100)) percent")
    }

    private var color: Color { level > 0.9 ? .red : level > 0.7 ? .yellow : .green }
}
