import GreenRoomCore
import SwiftUI

/// Everything that used to crowd the gear menu, in one window.
struct SettingsView: View {
    let monitor: DeviceMonitor
    let updater: Updater
    let callWatcher: CallWatcher
    let hotKey: HotKey

    @State private var openAtLogin = LoginItem.isEnabled
    @State private var useHotKey = HotKey.isEnabled
    @State private var alerts = Alerts.isEnabled
    @State private var keepSetup = KeepSetup.isEnabled
    @State private var checkCalls = CallWatcher.isEnabled && CallWatcher.hasAccess
    @State private var autoUpdate = true

    var body: some View {
        Form {
            Section("General") {
                Toggle("Open at login", isOn: $openAtLogin)
                Toggle(isOn: $useHotKey) {
                    Text("Open the panel with \(HotKey.label)")
                    if hotKey.isTaken {
                        Text("Another app already uses this shortcut.").foregroundStyle(.orange)
                    }
                }
            }
            Section("Alerts") {
                Toggle(isOn: $alerts) {
                    Text("Alert me when devices change")
                    Text("A device unplugs, your setup stops matching, a headset drops to call quality, "
                         + "or a recording app starts with something off.")
                }
                Toggle(isOn: $keepSetup) {
                    Text("Switch back when AirPods take over")
                    Text("Only devices that just connected. Anything you pick yourself stays.")
                }
                Toggle(isOn: $checkCalls) {
                    Text("Check before calendar calls")
                    Text("Two minutes before events with a Zoom, Meet, or Teams link. Needs calendar access.")
                }
            }
            Section("Setups") {
                if monitor.setups.isEmpty {
                    Text("No setups yet. Save one from the panel.").foregroundStyle(.secondary)
                }
                ForEach(monitor.setups, id: \.name) { setup in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(setup.name)
                            Text(DeviceKind.allCases.compactMap { monitor.names.apply(setup).devices[$0]?.name }
                                .joined(separator: " · "))
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        if setup.name == monitor.setup?.name {
                            Text("In use").font(.caption).foregroundStyle(.secondary)
                        } else {
                            Button("Apply") { monitor.apply(setup) }
                        }
                        Button("Forget", role: .destructive) { monitor.forget(setup) }
                    }
                }
            }
            Section {
                ForEach(uniqueDevices) { device in
                    DeviceNameRow(device: device, monitor: monitor)
                }
            } header: {
                Text("Devices")
            } footer: {
                Text("Your names show everywhere in Green Room. Hidden devices leave the pickers.")
            }
            if !monitor.ignoredApps.isEmpty {
                Section {
                    ForEach(monitor.ignoredApps.sorted(), id: \.self) { app in
                        HStack {
                            Text(app)
                            Spacer()
                            Button("Stop Ignoring") { monitor.stopIgnoring(app: app) }
                        }
                    }
                } header: {
                    Text("Ignored apps")
                } footer: {
                    Text("Ignored apps don't show as live on a device and never trigger a warning.")
                }
            }
            Section("Updates") {
                Toggle("Check for updates automatically", isOn: $autoUpdate)
                Button("Check Now") { updater.checkForUpdates() }
            }
        }
        .formStyle(.grouped)
        // A grouped form scrolls, so it has no height of its own; give the window one.
        .frame(width: 480, height: 640)
        .onAppear { autoUpdate = updater.checksAutomatically }
        .onChange(of: openAtLogin) { openAtLogin = LoginItem.set(openAtLogin) }
        .onChange(of: useHotKey) {
            HotKey.isEnabled = useHotKey
            hotKey.apply()
        }
        .onChange(of: alerts) { Alerts.isEnabled = alerts }
        .onChange(of: keepSetup) { KeepSetup.isEnabled = keepSetup }
        .onChange(of: checkCalls) {
            guard checkCalls != (CallWatcher.isEnabled && CallWatcher.hasAccess) else { return }
            Task { checkCalls = await callWatcher.setEnabled(checkCalls) }
        }
        .onChange(of: autoUpdate) { updater.checksAutomatically = autoUpdate }
    }

    /// A USB mic with a headphone jack is a mic and a speaker with one ID; it gets one row.
    private var uniqueDevices: [Device] {
        var seen = Set<String>()
        return monitor.systemDevices.filter { seen.insert($0.id).inserted }
    }
}

/// Rename a device, or hide it from the pickers.
struct DeviceNameRow: View {
    let device: Device
    let monitor: DeviceMonitor

    var body: some View {
        let nickname = monitor.names.nicknames[device.id]
        let hidden = monitor.names.isHidden(device)
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(nickname ?? device.name)
                Text(caption(renamed: nickname != nil, hidden: hidden))
                    .font(.caption).foregroundStyle(.secondary)
            }
            .opacity(hidden ? 0.5 : 1)
            Spacer()
            Menu {
                Button("Rename…") {
                    if let name = NamePrompt.ask(
                        title: "Rename \(device.name)", info: "Green Room shows this name everywhere.",
                        suggestion: nickname ?? device.name
                    ) {
                        monitor.rename(device, to: name)
                    }
                }
                if nickname != nil {
                    Button("Use “\(device.name)”") { monitor.rename(device, to: "") }
                }
                Button(hidden ? "Show in Lists" : "Hide from Lists") { monitor.setHidden(device, !hidden) }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
            .accessibilityLabel("Options for \(nickname ?? device.name)")
        }
    }

    private func caption(renamed: Bool, hidden: Bool) -> String {
        var parts = [device.kind.title, device.transport.label]
        if renamed { parts.append(device.name) }
        if hidden { parts.append("Hidden") }
        return parts.joined(separator: " · ")
    }
}
