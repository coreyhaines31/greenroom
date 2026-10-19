import GreenRoomCore
import SwiftUI

/// The camera as big as the screen, with the mic and speaker underneath, to check a shot
/// before recording. Shows the whole frame, so nothing at the edges is a surprise.
struct RecordPreviewView: View {
    let monitor: DeviceMonitor
    let checks: Checks
    let close: () -> Void

    var body: some View {
        // The controls sit under the picture, not over it, so the whole shot stays visible.
        VStack(spacing: 0) {
            Group {
                if checks.cameraAccess == .authorized, monitor.previewCamera != nil {
                    CameraPreview(session: checks.camera.session, gravity: .resizeAspect)
                } else {
                    Text(cameraMessage).font(.title3).foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            controls
        }
        .background(.black)
        .frame(minWidth: 720, minHeight: 480)
        .environment(\.colorScheme, .dark)
        .onChange(of: monitor.previewCamera) { checks.restartCamera() }
        .onChange(of: monitor.snapshot.active(.microphone)) { checks.restartMeter() }
    }

    private var cameraMessage: String {
        if monitor.snapshot.devices(.camera).isEmpty { return "No camera connected" }
        return switch checks.cameraAccess {
        case .denied, .restricted: "Allow camera access in System Settings › Privacy & Security"
        default: "Starting camera…"
        }
    }

    /// One row on a wide screen, two on a small one like a teleprompter.
    private var controls: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .top, spacing: 28) {
                cameraColumn
                micColumn
                speakerColumn
                Spacer(minLength: 0)
                doneColumn
            }
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 28) {
                    cameraColumn
                    micColumn
                }
                HStack(alignment: .top, spacing: 28) {
                    speakerColumn
                    Spacer(minLength: 0)
                    doneColumn
                }
            }
        }
        .padding(18)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        .padding(16)
    }

    private var cameraColumn: some View {
        VStack(alignment: .leading, spacing: 8) {
            DevicePicker(kind: .camera, monitor: monitor, selected: monitor.previewCamera)
            if let advice = checks.camera.advice {
                Label(advice, systemImage: "lightbulb").font(.caption).foregroundStyle(.secondary)
            }
        }
        .fixedSize()
    }

    private var micColumn: some View {
        VStack(alignment: .leading, spacing: 8) {
            DevicePicker(kind: .microphone, monitor: monitor, selected: monitor.snapshot.active(.microphone)) {
                Button(checks.playback.buttonTitle) { checks.hearYourself() }
                    .fixedSize()
                    .disabled(checks.micAccess != .authorized || checks.playback.phase != .idle)
            }
            LevelMeter(level: checks.meter.level).frame(minWidth: 280)
            if let problem = monitor.micProblem ?? (checks.meter.isSilent ? .silent : nil) {
                Label(problem.message, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption).foregroundStyle(.orange)
            }
        }
        .fixedSize()
    }

    private var speakerColumn: some View {
        DevicePicker(kind: .speaker, monitor: monitor, selected: monitor.snapshot.active(.speaker)) {
            Button(checks.tone.buttonTitle) { checks.tone.play() }
                .fixedSize()
                .disabled(checks.tone.playing != nil)
        }
        .fixedSize()
    }

    private var doneColumn: some View {
        VStack(alignment: .trailing, spacing: 12) {
            Button("Done", action: close)
                .keyboardShortcut(.cancelAction)
                .help("Close the preview (Esc)")
            RecordingSection(monitor: monitor)
        }
        .fixedSize()
    }
}
