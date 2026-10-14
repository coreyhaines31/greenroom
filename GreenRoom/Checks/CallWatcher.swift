import EventKit
import Foundation
import GreenRoomCore

/// Two minutes before a calendar event with a video-call link, checks your setup. Ready: says
/// nothing. Not ready: one alert with the fix. Opt-in, since it needs calendar access.
@MainActor
final class CallWatcher {
    private let monitor: DeviceMonitor
    private let alerts: Alerts
    private let store = EKEventStore()
    private var timer: Timer?
    /// Events already checked, so each call gets at most one alert.
    private var checked: Set<String> = []

    static let enabledKey = "checkBeforeCalls"
    /// How far ahead to check: an event starting between one and two and a half minutes from now.
    static let lead: ClosedRange<TimeInterval> = 60...150

    static var isEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: enabledKey) }
        set { UserDefaults.standard.set(newValue, forKey: enabledKey) }
    }

    static var hasAccess: Bool { EKEventStore.authorizationStatus(for: .event) == .fullAccess }

    init(monitor: DeviceMonitor, alerts: Alerts) {
        self.monitor = monitor
        self.alerts = alerts
    }

    func start() {
        guard Self.isEnabled, Self.hasAccess else { return }
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { _ in
            MainActor.assumeIsolated { [weak self] in self?.check() }
        }
        check()
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    /// Turns the check on or off. Returns whether it's on, since calendar access can be refused.
    func setEnabled(_ enabled: Bool) async -> Bool {
        guard enabled else {
            Self.isEnabled = false
            stop()
            return false
        }
        if !Self.hasAccess {
            _ = try? await store.requestFullAccessToEvents()
        }
        Self.isEnabled = Self.hasAccess
        start()
        return Self.isEnabled
    }

    private func check() {
        let now = Date.now
        let window = now.addingTimeInterval(Self.lead.lowerBound)...now.addingTimeInterval(Self.lead.upperBound)
        let predicate = store.predicateForEvents(withStart: now, end: window.upperBound, calendars: nil)
        let calls = store.events(matching: predicate).filter { event in
            !event.isAllDay && window.contains(event.startDate)
                && CallLinks.isVideoCall([event.location, event.notes, event.url?.absoluteString])
        }
        for event in calls {
            let key = "\(event.calendarItemIdentifier)-\(event.startDate.timeIntervalSince1970)"
            guard checked.insert(key).inserted else { continue }
            monitor.refresh(force: true)
            let problems = CallLinks.preCallProblems(readiness: monitor.readiness)
            guard let first = problems.first else { continue }
            let title = event.title.flatMap { $0.isEmpty ? nil : $0 } ?? "Your call"
            let more = problems.count > 1 ? " And \(problems.count - 1) more in Green Room." : ""
            alerts.sendCallCheck(
                title: "\(title) starts in 2 minutes", body: first.message + "." + more, fix: first.fix
            )
        }
    }
}
