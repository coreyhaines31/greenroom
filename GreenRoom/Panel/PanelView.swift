import AVFoundation
import GreenRoomCore
import SwiftUI

struct PanelView: View {
    let monitor: DeviceMonitor
    let checks: Checks

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            StatusHeader(readiness: monitor.readiness, setupName: monitor.setup?.name)
            cameraSection
            microphoneSection
            speakerSection
            Divider()
            footer
        }
        .padding(16)
        .frame(width: 340)
        .onChange(of: monitor.previewCamera) { checks.restartCamera() }
        .onChange(of: monitor.snapshot.active(.microphone)) { checks.restartMeter() }
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
            DevicePicker(kind: .microphone, monitor: monitor, selected: monitor.snapshot.active(.microphone))
            if checks.micAccess == .denied || checks.micAccess == .restricted {
                Text("Allow microphone access in System Settings › Privacy & Security")
                    .font(.caption).foregroundStyle(.secondary)
            } else {
                LevelMeter(level: checks.meter.level)
            }
        }
    }

    private var speakerSection: some View {
        HStack(alignment: .bottom) {
            DevicePicker(kind: .speaker, monitor: monitor, selected: monitor.snapshot.active(.speaker))
            Button(toneLabel) { checks.tone.play() }
                .disabled(checks.tone.playing != nil)
        }
    }

    private var toneLabel: String {
        switch checks.tone.playing {
        case .left: "Left…"
        case .right: "Right…"
        case nil: "Test"
        }
    }

    private var footer: some View {
        HStack {
            if monitor.setup == nil {
                Button("Save as my setup") { monitor.saveSetup() }
                    .help("Remember these devices and warn when something's different")
            } else {
                Menu("Setup") {
                    Button("Update to current devices") { monitor.saveSetup() }
                    Button("Forget setup") { monitor.forgetSetup() }
                }
                .fixedSize()
            }
            Spacer()
            Button("Quit") { NSApp.terminate(nil) }
        }
    }
}

struct StatusHeader: View {
    let readiness: Readiness
    let setupName: String?

    var body: some View {
        switch readiness {
        case .noSetup:
            Label("Pick your devices, then save them as your setup", systemImage: "web.camera")
                .font(.headline)
                .fixedSize(horizontal: false, vertical: true)
        case .ready:
            Label("Ready: \(setupName ?? "your setup")", systemImage: "checkmark.circle.fill")
                .font(.headline).foregroundStyle(.green)
        case .notReady(let issues):
            VStack(alignment: .leading, spacing: 4) {
                Label("Not ready", systemImage: "exclamationmark.triangle.fill")
                    .font(.headline).foregroundStyle(.orange)
                ForEach(issues, id: \.message) { issue in
                    Text(issue.message).font(.callout)
                }
            }
        }
    }
}

struct DevicePicker: View {
    let kind: DeviceKind
    let monitor: DeviceMonitor
    let selected: Device?

    var body: some View {
        let devices = monitor.snapshot.devices(kind)
        VStack(alignment: .leading, spacing: 4) {
            Text(kind.title).font(.caption).foregroundStyle(.secondary)
            picker(devices)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func picker(_ devices: [Device]) -> some View {
        Picker(kind.title, selection: Binding(
            get: { selected?.id ?? "" },
            set: { id in devices.first { $0.id == id }.map(monitor.select) }
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
