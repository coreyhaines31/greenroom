import AppKit
import EventKit
import GreenRoomCore
import Observation

@MainActor
@Observable
final class HoldCalls {
    private(set) var isEnabled = UserDefaults.standard.bool(forKey: "holdCalls")
    private(set) var usesCalendar = UserDefaults.standard.bool(forKey: "holdCallsCalendar")
    private(set) var shortcutReady = false
    private(set) var isBusy = false
    private(set) var status = "Install the shortcut, then check setup."
    @ObservationIgnored private let monitor: DeviceMonitor
    @ObservationIgnored private let calendar: CallWatcher
    @ObservationIgnored private var timer: Timer?
    @ObservationIgnored private var policy = CallHold()
    @ObservationIgnored private var generation = 0

    init(monitor: DeviceMonitor, calendar: CallWatcher) {
        self.monitor = monitor
        self.calendar = calendar
    }

    func start() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 15, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.check() }
        }
        if isEnabled { Task { await checkSetup() } }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        generation += 1
    }

    func setEnabled(_ enabled: Bool) {
        isEnabled = enabled && shortcutReady
        UserDefaults.standard.set(isEnabled, forKey: "holdCalls")
        generation += 1
        policy = CallHold()
        status = isEnabled ? "Waiting for a call." : "Off. Any current hold expires within two minutes."
        if isEnabled { check() }
    }

    func setCalendar(_ enabled: Bool) async {
        usesCalendar = enabled ? await calendar.requestAccess() : false
        UserDefaults.standard.set(usesCalendar, forKey: "holdCallsCalendar")
        check()
    }

    func installShortcut() {
        guard let url = Bundle.main.url(forResource: HoldShortcut.name, withExtension: "shortcut") else {
            status = "The bundled shortcut is missing. Reinstall Green Room."
            return
        }
        NSWorkspace.shared.open(url)
    }

    func checkSetup() async {
        guard !isBusy else { return }
        isBusy = true
        defer { isBusy = false }
        do {
            // A deliberately nonmatching input checks the protocol without changing Focus.
            shortcutReady = try await HoldShortcut.run("check") == "blocked"
            status = shortcutReady ? "Shortcut ready."
                : "Install the bundled shortcut again; its output was unexpected."
        } catch {
            shortcutReady = false
            status = error.localizedDescription
        }
        if !shortcutReady {
            isEnabled = false
            UserDefaults.standard.set(false, forKey: "holdCalls")
        }
    }

    func check() {
        guard isEnabled, shortcutReady, !isBusy else { return }
        let now = Date.now
        let devices = CallHold.hasDeviceSignal(monitor.snapshot, ignoring: monitor.ignoredApps)
        let event = usesCalendar && calendar.hasCurrentCall(at: now)
        guard let expected = policy.request(active: devices || event, now: now) else {
            if policy.isPaused {
                status = "Paused for this call: Focus changed or a hold could not be renewed."
            } else if let end = policy.heldUntil, end > now {
                status = "Holding calls. Ends within two minutes after activity stops."
            } else {
                status = "Waiting for a call."
            }
            return
        }
        isBusy = true
        let version = generation
        Task {
            defer { isBusy = false }
            do {
                let result = try await HoldShortcut.run(expected)
                guard version == generation else { return }
                policy.completed(result, startedAt: now, now: .now)
                status = policy.isPaused ? "Another Focus is active or changed. Leaving it alone for this call."
                    : "Holding calls with Do Not Disturb."
            } catch {
                guard version == generation else { return }
                policy.completed("failed", startedAt: now, now: .now)
                status = "Hold paused: \(error.localizedDescription)"
            }
        }
    }
}
