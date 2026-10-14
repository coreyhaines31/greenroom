import AppKit
import GreenRoomCore

/// The right-click menu: setups and devices, switched in one click without opening the panel.
@MainActor
enum QuickMenu {
    static func make(
        monitor: DeviceMonitor, openPanel: @escaping () -> Void, openSettings: @escaping () -> Void
    ) -> NSMenu {
        let menu = NSMenu()
        if !monitor.setups.isEmpty {
            menu.addItem(.sectionHeader(title: "Setups"))
            for setup in monitor.setups {
                let item = ClosureMenuItem(setup.name) { monitor.apply(setup) }
                item.state = setup.name == monitor.setup?.name ? .on : .off
                menu.addItem(item)
            }
            menu.addItem(.separator())
        }
        for kind in [DeviceKind.microphone, .speaker, .camera] {
            let devices = monitor.snapshot.devices(kind)
            guard !devices.isEmpty else { continue }
            menu.addItem(.sectionHeader(title: kind.title))
            let selected = kind == .camera ? monitor.previewCamera : monitor.snapshot.active(kind)
            for device in devices {
                let live = monitor.snapshot.liveApps(device)
                let title = live.isEmpty ? device.name : "\(device.name) · live in \(live.joined(separator: ", "))"
                let item = ClosureMenuItem(title) { monitor.select(device) }
                item.state = device.id == selected?.id ? .on : .off
                menu.addItem(item)
            }
            menu.addItem(.separator())
        }
        menu.addItem(ClosureMenuItem("Open Green Room", handler: openPanel))
        menu.addItem(ClosureMenuItem("Settings…", keyEquivalent: ",", handler: openSettings))
        menu.addItem(ClosureMenuItem("Quit Green Room", keyEquivalent: "q") { NSApp.terminate(nil) })
        return menu
    }
}
