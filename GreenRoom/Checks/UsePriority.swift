import Foundation
import GreenRoomCore

/// Switches to the highest device in your order when devices connect or disconnect, so
/// AirPods or an iPhone camera never take over, and a mic you unplug falls back to the next
/// one you chose. Opt-in. A device you just picked yourself stays.
@MainActor
final class UsePriority {
    private let monitor: DeviceMonitor

    static let enabledKey = "usePriority"

    static var isEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: enabledKey) }
        set { UserDefaults.standard.set(newValue, forKey: enabledKey) }
    }

    init(monitor: DeviceMonitor) {
        self.monitor = monitor
    }

    func devicesChanged(_ events: [DeviceHistory.Event]) {
        guard Self.isEnabled, events.contains(where: { $0.change != .selected }) else { return }
        let yours = monitor.chosenRecently(within: Takeover.window)
        for kind in DeviceKind.allCases {
            guard let best = monitor.priorities.best(kind, in: monitor.snapshot) else { continue }
            let current = kind == .camera ? monitor.previewCamera : monitor.snapshot.active(kind)
            guard current?.id != best.id, !(current.map { yours.contains($0.id) } ?? false) else { continue }
            monitor.select(best, byYou: false)
        }
    }
}
