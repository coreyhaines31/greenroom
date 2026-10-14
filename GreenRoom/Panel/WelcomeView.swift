import AppKit
import GreenRoomCore
import SwiftUI

/// Shown once. Proposes your setup from what you've used, offers the opt-in features in one
/// place, and points to the icon and the shortcut.
struct WelcomeView: View {
    let monitor: DeviceMonitor
    let callWatcher: CallWatcher
    let done: () -> Void

    @State private var alerts = Alerts.isEnabled
    @State private var keepSetup = KeepSetup.isEnabled
    @State private var checkCalls = CallWatcher.isEnabled && CallWatcher.hasAccess
    /// On by default for a new install, like the other Mac apps in the family.
    @State private var openAtLogin = true

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(spacing: 14) {
                Image(nsImage: NSApp.applicationIconImage).resizable().frame(width: 56, height: 56)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Welcome to Green Room").font(.title2.weight(.semibold))
                    Text("Check your camera, mic, and speakers before you go on.").foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            setupSection

            VStack(alignment: .leading, spacing: 8) {
                Text("Speak up when").font(.headline)
                Toggle("A device unplugs or my setup stops matching", isOn: $alerts)
                Toggle("AirPods take over the sound (and switch back)", isOn: $keepSetup)
                Toggle("A calendar call starts soon and I'm not ready", isOn: $checkCalls)
                    .onChange(of: checkCalls) {
                        guard checkCalls != (CallWatcher.isEnabled && CallWatcher.hasAccess) else { return }
                        Task { checkCalls = await callWatcher.setEnabled(checkCalls) }
                    }
            }

            Toggle("Open Green Room at login", isOn: $openAtLogin)

            Text("Open it any time from the camera icon in the menu bar, or press \(HotKey.label).")
                .font(.callout).foregroundStyle(.secondary)

            HStack {
                Spacer()
                Button("Done") { finish() }
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 460)
    }

    @ViewBuilder
    private var setupSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Your usual devices").font(.headline)
            let proposal = monitor.proposedSetup
            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 4) {
                ForEach(DeviceKind.allCases, id: \.self) { kind in
                    if let device = proposal.devices[kind] {
                        GridRow {
                            Text(kind.title).foregroundStyle(.secondary)
                            Text("\(device.name) · \(device.transport.label)")
                        }
                    }
                }
            }
            if monitor.setups.isEmpty {
                Text("Picked from what you've used most. Change it any time in the Setup menu.")
                    .font(.caption).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Button("Save as My Setup") { monitor.saveSetup() }
            } else {
                Label("Saved as \(monitor.setups.first?.name ?? "your setup")", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            }
        }
    }

    private func finish() {
        Alerts.isEnabled = alerts
        KeepSetup.isEnabled = keepSetup
        _ = LoginItem.set(openAtLogin)
        done()
    }
}
