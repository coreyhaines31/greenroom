import AppKit
import GreenRoomCore
import SwiftUI

/// Setups for each place you work. The one that fits what's plugged in is checked; picking
/// another applies its devices.
struct SetupMenu: View {
    let monitor: DeviceMonitor
    /// The name dialog is modal, so the panel closes first instead of vanishing under it.
    let closePanel: () -> Void

    var body: some View {
        Menu(monitor.setup?.name ?? "Setup") {
            ForEach(monitor.setups, id: \.name) { setup in
                Button {
                    monitor.apply(setup)
                } label: {
                    if setup.name == monitor.setup?.name {
                        Label(setup.name, systemImage: "checkmark")
                    } else {
                        Text(setup.name)
                    }
                }
            }
            Divider()
            if let current = monitor.setup {
                Button("Update \(current.name) to Current Devices") { monitor.saveSetup() }
            }
            Button("Save Current Devices as New Setup…") {
                closePanel()
                if let name = NamePrompt.ask(suggestion: suggestedName) { monitor.saveNewSetup(named: name) }
            }
            if let current = monitor.setup {
                Button("Forget \(current.name)") { monitor.forget(current) }
            }
        }
        .fixedSize()
        .help("Your setups. Green Room checks the one that fits what's plugged in.")
    }

    private var suggestedName: String {
        let taken = Set(monitor.setups.map(\.name))
        let names = ["Desk", "Studio", "Travel", "Office", "Home"]
        return names.first { !taken.contains($0) } ?? "Setup \(taken.count + 1)"
    }
}

enum NamePrompt {
    @MainActor
    static func ask(suggestion: String) -> String? {
        let alert = NSAlert()
        alert.messageText = "Name this setup"
        alert.informativeText = "Green Room picks the setup whose devices are plugged in, "
            + "so name it for the place, like Desk or Travel."
        let field = NSTextField(string: suggestion)
        field.frame = NSRect(x: 0, y: 0, width: 240, height: 24)
        alert.accessoryView = field
        alert.addButton(withTitle: "Save")
        alert.addButton(withTitle: "Cancel")
        alert.window.initialFirstResponder = field
        NSApp.activate()
        guard alert.runModal() == .alertFirstButtonReturn else { return nil }
        let name = field.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty ? nil : name
    }
}
