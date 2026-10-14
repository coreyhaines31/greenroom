import Foundation
import GreenRoomCore
import UserNotifications

/// Sends a notification when your setup stops matching, or a usual device disappears.
/// Waits a few seconds first: devices often drop and come back while reconnecting.
@MainActor
final class Alerts {
    private let monitor: DeviceMonitor
    private var buffered: [DeviceHistory.Event] = []
    private var pending: Task<Void, Never>?
    /// Mismatches already announced, so each one alerts once until it's fixed.
    private var announced: Set<String> = []

    static let enabledKey = "alertsEnabled"
    static let settleSeconds = 3.0
    /// Wired devices only. iPhones, AirPods, and display speakers come and go all day.
    static let alertable: Set<Transport> = [.usb, .external, .thunderbolt]

    static var isEnabled: Bool {
        get { UserDefaults.standard.object(forKey: enabledKey) as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: enabledKey) }
    }

    init(monitor: DeviceMonitor) {
        self.monitor = monitor
        announced = Set(Self.mismatches(monitor.readiness).map(\.message))
    }

    func start() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    func devicesChanged(_ events: [DeviceHistory.Event]) {
        buffered += events
        pending?.cancel()
        pending = Task {
            try? await Task.sleep(for: .seconds(Self.settleSeconds))
            guard !Task.isCancelled else { return }
            check()
        }
    }

    private func check() {
        let events = buffered
        buffered = []
        let mismatches = Self.mismatches(monitor.readiness)
        let fresh = mismatches.filter { !announced.contains($0.message) }
        announced = Set(mismatches.map(\.message))
        guard Self.isEnabled else { return }

        for mismatch in fresh {
            let detail = mismatch.problem == .missing
                ? monitor.missingDevice(mismatch.expected, lastSeen: nil).reason.advice
                : "Open Green Room to switch back."
            send(title: mismatch.message, body: detail)
        }
        let covered = Set(fresh.map(\.expected.id))
        var seen = Set<String>()
        let gone = events.filter { event in
            let device = event.device
            guard event.change == .disconnected, Self.alertable.contains(device.transport),
                  !covered.contains(device.id), seen.insert(device.name).inserted,
                  !monitor.snapshot.contains(device.id, kind: device.kind),
                  let record = monitor.history.record(for: device) else { return false }
            return monitor.history.isUsual(record, now: .now)
        }.map(\.device)
        if gone.count == 1, let device = gone.first {
            let reason = monitor.missingDevice(device, lastSeen: nil).reason
            send(title: "\(device.name) disconnected", body: "\(reason.headline). \(reason.advice)")
        } else if gone.count > 1 {
            // Usually a dock or hub coming out: one alert, not one per device.
            let names = ListFormatter.localizedString(byJoining: gone.map(\.name))
            send(title: "\(gone.count) devices disconnected", body: "\(names). Check the dock or hub they share.")
        }
    }

    private func send(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        UNUserNotificationCenter.current().add(
            UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        )
    }

    private static func mismatches(_ readiness: Readiness) -> [Mismatch] {
        if case .notReady(let mismatches) = readiness { return mismatches }
        return []
    }
}
