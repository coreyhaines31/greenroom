import Foundation
import GreenRoomCore

/// Switches back to the setup's mic or speaker when a device that just connected takes over.
/// Opt-in. Keeping the new device from the alert exempts it until it disconnects.
@MainActor
final class KeepSetup {
    private let monitor: DeviceMonitor
    private let alerts: Alerts
    private var exempt: Set<String> = []

    static let enabledKey = "keepSetup"

    static var isEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: enabledKey) }
        set { UserDefaults.standard.set(newValue, forKey: enabledKey) }
    }

    init(monitor: DeviceMonitor, alerts: Alerts) {
        self.monitor = monitor
        self.alerts = alerts
        alerts.onKeep = { [weak self] kind, deviceID in self?.keep(kind: kind, deviceID: deviceID) }
    }

    func devicesChanged(_ events: [DeviceHistory.Event]) {
        for event in events where event.change == .disconnected {
            exempt.remove(event.device.id)
        }
        // Your priority order covers takeovers too, and the two would fight.
        guard Self.isEnabled, !UsePriority.isEnabled else { return }
        let takeovers = Takeover.detect(
            events: events, timeline: monitor.history.events, setup: monitor.setup, snapshot: monitor.snapshot,
            exempt: exempt.union(monitor.chosenRecently(within: Takeover.window))
        )
        for takeover in takeovers {
            monitor.select(takeover.restore, byYou: false)
            // Only say we switched back if it worked.
            if monitor.snapshot.active(takeover.kind)?.id == takeover.restore.id {
                alerts.sendTakeover(takeover)
            }
        }
    }

    /// "Use AirPods Pro" from the alert: switch to it and leave it alone until it disconnects.
    func keep(kind: DeviceKind, deviceID: String) {
        exempt.insert(deviceID)
        if let device = monitor.snapshot.device(deviceID, kind: kind) {
            monitor.select(device)
        }
    }
}
