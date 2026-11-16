import AppKit
import PanelKit
import SwiftUI

/// The bottom of the panel: your setup (or saving one), History, and the gear menu.
struct PanelFooter: View {
    let monitor: DeviceMonitor
    let updater: Updater
    let closePanel: () -> Void
    let showHistory: () -> Void
    let showSettings: () -> Void

    var body: some View {
        HStack(spacing: 6) {
            if monitor.setups.isEmpty {
                Button("Save as my setup") { monitor.saveSetup() }
                    .buttonStyle(.panelCompact)
                    .help("Remember these devices and warn when something's different")
            } else {
                SetupMenu(monitor: monitor, closePanel: closePanel)
            }
            Button("History") { showHistory() }
                .buttonStyle(.panelCompact)
            Spacer()
            OptionsMenu(updater: updater, showSettings: showSettings)
        }
        .padding(.top, 9)
        .padding(.bottom, 10)
        .padding(.horizontal, 14)
        .overlay(alignment: .top) { PanelHairline() }
    }
}

/// Settings, updates, feedback, and quit. The toggles live in the Settings window.
struct OptionsMenu: View {
    let updater: Updater
    let showSettings: () -> Void
    @Environment(\.panelTheme) private var theme

    var body: some View {
        Menu {
            Button("Settings…", action: showSettings)
                .keyboardShortcut(",")
            Button("Check for Updates…") { updater.checkForUpdates() }
            Button("Send Feedback…") { Feedback.open() }
            Divider()
            Button("Quit Green Room") { NSApp.terminate(nil) }
        } label: {
            Image(systemName: "gearshape")
                .font(.system(size: 13))
                .foregroundStyle(theme.sub)
                .frame(width: 24, height: 22)
                .contentShape(Rectangle())
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .menuIndicator(.hidden)
        .fixedSize()
        .help("Settings, Check for Updates, Send Feedback, Quit")
        .accessibilityLabel("Options")
    }
}
