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
    nonisolated static let keepAction = "keep"
    /// Called when "Use <device>" is picked on a takeover alert.
    var onKeep: ((DeviceKind, String) -> Void)?
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

    /// The before-the-call heads-up. Sent whether or not other alerts are on, since you turned
    /// this check on by itself.
    func sendCallCheck(title: String, body: String, fix: Device?) {
        send(title: title, body: body, fix: fix)
    }

    /// "Loom started recording: check your camera." No fix button: the fixes live in the
    /// recording app's own settings or on the desk.
    func sendRecordingCheck(title: String, body: String) {
        send(title: title, body: body)
    }

    /// Tells you Green Room switched back, with a button to keep the device that took over.
    func sendTakeover(_ takeover: Takeover) {
        let lead = takeover.kind == .speaker ? "took over the sound" : "took over the mic"
        send(
            title: "\(takeover.intruder.name) \(lead)",
            body: "Switched back to \(takeover.restore.name), your setup's \(takeover.kind.title.lowercased()).",
            fix: takeover.intruder, verb: "Use", action: Self.keepAction
        )
    }

    private func send(
        title: String, body: String, fix: Device? = nil, verb: String = "Switch to", action: String = Alerts.fixAction
    ) {
        let center = UNUserNotificationCenter.current()
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        if let fix {
            let label = "\(verb) \(fix.name)"
            let category = "\(action):\(label)"
            if categories[category] == nil {
                categories[category] = UNNotificationCategory(
                    identifier: category,
                    actions: [UNNotificationAction(identifier: action, title: label)],
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
        let action = response.actionIdentifier
        guard action == Self.fixAction || action == Self.keepAction else { return }
        let info = response.notification.request.content.userInfo
        guard let kind = (info["kind"] as? String).flatMap(DeviceKind.init(rawValue:)),
              let deviceID = info["deviceID"] as? String else { return }
        if action == Self.keepAction {
            await MainActor.run { onKeep?(kind, deviceID) }
            return
        }
        await MainActor.run {
            monitor.refresh(force: true)
            // An old banner shouldn't switch devices if the problem is already gone.
            let fixes = Self.mismatches(monitor.readiness).compactMap(\.fix) + monitor.advisories.compactMap(\.fix)
            if let device = fixes.first(where: { $0.id == deviceID && $0.kind == kind }) {
                monitor.select(device)
            }
        }
    }
}
