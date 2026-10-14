import Foundation
import GreenRoomCore
import UserNotifications

/// Sends a notification when your setup stops matching, a usual device disappears, or a headset
/// drops into call mode. Waits a few seconds first: devices often drop and come back while
/// reconnecting. Alerts that have a fix carry a button that applies it.
@MainActor
final class Alerts: NSObject, UNUserNotificationCenterDelegate {
    private let monitor: DeviceMonitor
    private var buffered: [DeviceHistory.Event] = []
    private var pending: Task<Void, Never>?
    /// Problems already announced, so each one alerts once until it's gone.
    private var announced: Set<String> = []
    /// One category per fix, since a notification's button title comes from its category.
    private var categories: [String: UNNotificationCategory] = [:]

    static let enabledKey = "alertsEnabled"
    static let settleSeconds = 3.0
    nonisolated static let fixAction = "fix"
    /// Wired devices only. iPhones, AirPods, and display speakers come and go all day.
    static let alertable: Set<Transport> = [.usb, .external, .thunderbolt]

    static var isEnabled: Bool {
        get { UserDefaults.standard.object(forKey: enabledKey) as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: enabledKey) }
    }

    init(monitor: DeviceMonitor) {
        self.monitor = monitor
        super.init()
        announced = currentProblems()
    }

    func start() {
        let center = UNUserNotificationCenter.current()
        center.delegate = self
        center.requestAuthorization(options: [.alert, .sound]) { _, _ in }
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

    private func currentProblems() -> Set<String> {
        Set(Self.mismatches(monitor.readiness).map(\.message) + monitor.advisories.map(\.title))
    }

    private func check() {
        let events = buffered
        buffered = []
        let mismatches = Self.mismatches(monitor.readiness)
        let advisories = monitor.advisories
        let freshMismatches = mismatches.filter { !announced.contains($0.message) }
        let freshAdvisories = advisories.filter { !announced.contains($0.title) }
        announced = currentProblems()
        guard Self.isEnabled else { return }

        for mismatch in freshMismatches {
            let detail = mismatch.problem == .missing
                ? monitor.missingDevice(mismatch.expected, lastSeen: nil).reason.advice
                : mismatch.advice ?? "Switch back from here, or in Green Room."
            send(title: mismatch.message, body: detail, fix: mismatch.fix, verb: "Switch to")
        }
        for advisory in freshAdvisories {
            send(title: advisory.title, body: advisory.message, fix: advisory.fix, verb: "Use")
        }
        let covered = Set(freshMismatches.map(\.expected.id))
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

    private func send(title: String, body: String, fix: Device? = nil, verb: String = "Switch to") {
        let center = UNUserNotificationCenter.current()
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        if let fix {
            let label = "\(verb) \(fix.name)"
            let category = "fix:\(label)"
            if categories[category] == nil {
                categories[category] = UNNotificationCategory(
                    identifier: category,
                    actions: [UNNotificationAction(identifier: Self.fixAction, title: label)],
                    intentIdentifiers: []
                )
                center.setNotificationCategories(Set(categories.values))
            }
            content.categoryIdentifier = category
            content.userInfo = ["kind": fix.kind.rawValue, "deviceID": fix.id]
        }
        center.add(UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil))
    }

    private static func mismatches(_ readiness: Readiness) -> [Mismatch] {
        if case .notReady(let mismatches) = readiness { return mismatches }
        return []
    }

    // MARK: UNUserNotificationCenterDelegate

    /// Show alerts even while Green Room's panel is open.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter, willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse
    ) async {
        guard response.actionIdentifier == Self.fixAction else { return }
        let info = response.notification.request.content.userInfo
        guard let kind = (info["kind"] as? String).flatMap(DeviceKind.init(rawValue:)),
              let deviceID = info["deviceID"] as? String else { return }
        await MainActor.run {
            monitor.refresh()
            if let device = monitor.snapshot.device(deviceID, kind: kind) {
                monitor.select(device)
            }
        }
    }
}
