import AppKit
import AVFoundation
import GreenRoomCore
import Observation

@MainActor
@Observable
final class MicWatch {
    private(set) var isEnabled = UserDefaults.standard.bool(forKey: "checkMicOnUse")
    private(set) var status = "Checks briefly when another app opens a mic. Audio is never saved."
    @ObservationIgnored private let monitor: DeviceMonitor
    @ObservationIgnored private let warning = MicWarningPanel()
    @ObservationIgnored private var timer: Timer?
    @ObservationIgnored private var sessions = MicCheckSessions()
    @ObservationIgnored private var taps: [String: InputTap] = [:]
    @ObservationIgnored private var dismissed: Set<LiveUse> = []
    @ObservationIgnored private var shown: LiveUse?
    @ObservationIgnored private var lastTick: TimeInterval?

    static var isSupported: Bool {
        if #available(macOS 14.2, *) { return true }
        return false
    }

    init(monitor: DeviceMonitor) {
        self.monitor = monitor
    }

    func setEnabled(_ enabled: Bool) async {
        if enabled, AVCaptureDevice.authorizationStatus(for: .audio) == .notDetermined {
            _ = await AVCaptureDevice.requestAccess(for: .audio)
        }
        isEnabled = enabled && Self.isSupported && AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
        UserDefaults.standard.set(isEnabled, forKey: "checkMicOnUse")
        status = enabled && !isEnabled ? "Allow microphone access in System Settings → Privacy & Security."
            : "Checks briefly when another app opens a mic. Audio is never saved."
        start()
    }

    func start() {
        stop()
        guard isEnabled, Self.isSupported else { return }
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
        tick()
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        reset()
    }

    private func reset() {
        taps.values.forEach { $0.stop() }
        taps = [:]
        sessions = MicCheckSessions()
        dismissed = []
        shown = nil
        lastTick = nil
        warning.close()
    }

    private func tick() {
        guard AVCaptureDevice.authorizationStatus(for: .audio) == .authorized else {
            reset()
            status = "Allow microphone access in System Settings → Privacy & Security."
            return
        }
        let now = ProcessInfo.processInfo.systemUptime
        // After sleep or a stalled run loop, take a fresh sample instead of timing out an old check.
        if let lastTick, now - lastTick > 2 { reset() }
        lastTick = now
        var snapshot = monitor.snapshot
        snapshot.live = LiveDevices.current()
        sessions.reconcile(snapshot, ignoring: monitor.ignoredApps, now: now)
        dismissed.formIntersection(Set(sessions.checks.keys))
        let needed = sessions.pendingDeviceIDs
        stopTaps(except: needed)
        for id in needed where taps[id] == nil {
            if let device = snapshot.device(id, kind: .microphone) { taps[id] = InputTap(device) }
        }
        sessions.observe(taps.compactMapValues { $0.readSample() }, now: now)
        stopTaps(except: sessions.pendingDeviceIDs)
        showWarning(snapshot)
    }

    private func stopTaps(except needed: Set<String>) {
        for id in Array(taps.keys) where !needed.contains(id) {
            taps.removeValue(forKey: id)?.stop()
        }
    }

    private func showWarning(_ snapshot: Snapshot) {
        let problems = sessions.checks.filter {
            ($0.value.result == .silent || $0.value.result == .unavailable) && !dismissed.contains($0.key)
        }
        if let shown, problems[shown] != nil { return }
        guard let use = problems.keys.sorted(by: { ($0.app ?? "", $0.deviceID) < ($1.app ?? "", $1.deviceID) }).first,
              let device = snapshot.device(use.deviceID, kind: .microphone), let check = problems[use] else {
            warning.close()
            shown = nil
            return
        }
        shown = use
        let fallback = snapshot.devices(.microphone).first { $0.transport == .builtIn && $0.id != device.id }
        let content = MicWarningContent(device: device, app: use.app ?? "Another app",
                                        result: check.result, fallback: fallback)
        warning.show(content, switchMic: { [weak self] in
            self?.switchMic(for: use, to: fallback)
        }, dismiss: { [weak self] in
            self?.dismiss(use)
        }, ignore: { [weak self] in
            if let app = use.app { self?.monitor.ignore(app: app) }
            self?.dismiss(use)
        })
    }

    private func dismiss(_ use: LiveUse) {
        dismissed.insert(use)
        shown = nil
        warning.close()
    }

    private func switchMic(for use: LiveUse, to fallback: Device?) {
        guard let fallback, LiveDevices.current().contains(use) else { dismiss(use); return }
        monitor.refresh(force: true)
        if let device = monitor.snapshot.device(fallback.id, kind: .microphone) { monitor.select(device) }
        dismiss(use)
    }
}
