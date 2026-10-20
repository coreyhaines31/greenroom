import AppKit
import SwiftUI

struct HoldCallsSection: View {
    let hold: HoldCalls

    var body: some View {
        Section {
            Toggle("Hold calls and notifications", isOn: Binding(
                get: { hold.isEnabled }, set: { hold.setEnabled($0) }
            ))
            .disabled(!hold.shortcutReady || hold.isBusy)
            Text("Turns on Do Not Disturb while another app uses your mic or camera. "
                 + "Recorders count too. Ignored apps don't trigger mic holds. "
                 + "Mic detection needs macOS 14.2 or later.")
                .font(.caption).foregroundStyle(.secondary)
            Toggle("Include calendar calls", isOn: Binding(
                get: { hold.usesCalendar && CallWatcher.hasAccess },
                set: { value in Task { await hold.setCalendar(value) } }
            ))
            Text("From the start to the end of events with a video-call link. Uses the same calendar "
                 + "permission as pre-call checks, with a separate toggle.")
                .font(.caption).foregroundStyle(.secondary)
            HStack {
                Button("Install Shortcut…") { hold.installShortcut() }
                Button("Check Setup") { Task { await hold.checkSetup() } }
                    .disabled(hold.isBusy)
            }
            Text(hold.status).font(.caption).foregroundStyle(.secondary)
            DisclosureGroup("iPhone calls and Focus settings") {
                Text("To silence your iPhone too, turn on Share Across Devices in Focus settings. "
                     + "In Do Not Disturb, review allowed people and apps, and turn off repeated calls "
                     + "if you don't want them to ring through. Green Room can't verify these settings.")
                Text("macOS can't identify camera users. While Green Room previews a camera, that camera is excluded.")
                Text("For Continuity calls, you can also turn off Calls from iPhone in FaceTime settings.")
                Button("Open Focus Settings") {
                    if let url = URL(string: "x-apple.systempreferences:com.apple.Focus-Settings.extension") {
                        NSWorkspace.shared.open(url)
                    }
                }
            }
            .font(.caption)
        } header: {
            Text("Hold calls")
        } footer: {
            Text("Existing Focus modes are left alone. Holds expire within two minutes after activity stops, "
                 + "even if Green Room quits. Switch Focus or turn it off to pause for this call. "
                 + "Changing the duration of the same Do Not Disturb mode cannot be detected.")
        }
    }
}
