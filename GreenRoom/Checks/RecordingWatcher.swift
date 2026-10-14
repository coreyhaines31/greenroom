import Foundation
import GreenRoomCore

/// When a recording app (Loom, OBS, Screen Studio…) turns on the mic, runs "Ready to record?"
/// and alerts only if something would spoil the take. Once per recording: pausing and resuming
/// within a few minutes is the same recording.
@MainActor
final class RecordingWatcher {
    private let monitor: DeviceMonitor
    private let alerts: Alerts
    private var previous = Snapshot()
    /// When each recorder last had the mic.
    private var lastLive: [String: Date] = [:]

    /// Long enough for the app to pick its camera format.
    static let settle: Duration = .seconds(2)
    static let sameRecording: TimeInterval = 5 * 60

    init(monitor: DeviceMonitor, alerts: Alerts) {
        self.monitor = monitor
        self.alerts = alerts
    }

    func devicesChanged() {
        let now = monitor.snapshot.ignoring(apps: monitor.ignoredApps)
        let started = RecordingApps.started(before: previous, after: now)
        previous = now
        for app in started {
            let resumed = lastLive[app].map { Date.now.timeIntervalSince($0) < Self.sameRecording } ?? false
            if !resumed {
                Task {
                    try? await Task.sleep(for: Self.settle)
                    check(app)
                }
            }
        }
        for app in RecordingApps.started(before: Snapshot(), after: now) {
            lastLive[app] = .now
        }
    }

    private func check(_ app: String) {
        guard Alerts.isEnabled else { return }
        monitor.refresh(force: true)
        let snapshot = monitor.snapshot
        // Stopped within the settle time: nothing to warn about.
        guard RecordingApps.started(before: Snapshot(), after: snapshot).contains(app) else { return }
        lastLive[app] = .now
        // The camera the recorder has open, if macOS says so; otherwise the one in the panel.
        let camera = snapshot.devices(.camera).first(where: snapshot.isLive) ?? monitor.previewCamera
        let micInUse = snapshot.devices(.microphone).first { snapshot.liveApps($0).contains(app) }
        let check = RecordingCheck.evaluate(RecordingCheck.currentInputs(
            camera: camera, mic: micInUse ?? snapshot.active(.microphone), sampleRates: snapshot.sampleRates
        ))
        let problems = check.items.filter { !$0.passed }
        guard let first = problems.first else { return }
        let more = problems.count > 1 ? " And \(problems.count - 1) more under Ready to record? in Green Room." : ""
        alerts.sendRecordingCheck(title: "\(app) started recording: check your \(first.title.lowercased())",
                                  body: first.detail + more)
    }
}
