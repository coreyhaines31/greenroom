import AppKit
import GreenRoomCore
import SwiftUI

struct MicWarningContent {
    let device: Device
    let app: String
    let result: MicSignalCheck.Result
    let fallback: Device?
}

/// A nonactivating panel remains visible during Focus without interrupting typing or dictation.
@MainActor
final class MicWarningPanel {
    private var panel: NSPanel?

    func show(
        _ content: MicWarningContent,
        switchMic: @escaping () -> Void, dismiss: @escaping () -> Void, ignore: @escaping () -> Void
    ) {
        close()
        let view = MicWarningView(device: content.device, app: content.app, result: content.result,
                                  fallback: content.fallback,
                                  switchMic: switchMic, dismiss: dismiss, ignore: ignore)
        let panel = NSPanel(contentRect: .zero, styleMask: [.titled, .nonactivatingPanel],
                            backing: .buffered, defer: false)
        panel.title = "Green Room · Microphone check"
        panel.contentViewController = NSHostingController(rootView: view)
        panel.isReleasedWhenClosed = false
        panel.hidesOnDeactivate = false
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        if let frame = NSScreen.main?.visibleFrame {
            panel.setFrameTopLeftPoint(NSPoint(x: frame.maxX - panel.frame.width - 20, y: frame.maxY - 20))
        }
        panel.orderFrontRegardless()
        self.panel = panel
    }

    func close() {
        panel?.close()
        panel = nil
    }
}

private struct MicWarningView: View {
    let device: Device
    let app: String
    let result: MicSignalCheck.Result
    let fallback: Device?
    let switchMic: () -> Void
    let dismiss: () -> Void
    let ignore: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(result == .silent ? "No sound detected from your mic" : "Couldn't check your microphone",
                  systemImage: "mic.slash.fill")
                .font(.headline).foregroundStyle(.orange)
            Text("\(app) is using \(device.name).")
            Text(result == .silent
                 ? "No sound came through during the startup check. If your mic connects through a camera, "
                    + "make sure the camera is on. Check the mic's mute switch and gain, too."
                 : "Green Room couldn't read audio from this device. Check it before continuing your dictation.")
                .foregroundStyle(.secondary)
            if let fallback {
                Button("Use \(fallback.name) as Mac default", action: switchMic)
                Text("Then restart dictation. If \(app) has its own mic setting, select the mic there too.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            HStack {
                Button("Ignore \(app)", action: ignore)
                Spacer()
                Button("Dismiss", action: dismiss)
            }
        }
        .padding(20)
        .frame(width: 420)
        .fixedSize(horizontal: false, vertical: true)
    }
}
