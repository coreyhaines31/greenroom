import Foundation
import GreenRoomCore

/// When a recording app (Loom, OBS, Screen Studio…) turns on the mic, runs "Ready to record?"
/// and alerts only if something would spoil the take. Once per recording.
@MainActor
final class RecordingWatcher {
    private let monitor: DeviceMonitor
    private let alerts: Alerts
    private var previous = Snapshot()
    /// Recorders already checked while they keep the mic on.
    private var checked: Set<String> = []

    /// Long enough for the app to pick its camera format.
    static let settle: Duration = .seconds(2)

    init(monitor: DeviceMonitor, alerts: Alerts) {
        self.monitor = monitor
        self.alerts = alerts
    }

    func devicesChanged() {
        let now = monitor.snapshot.ignoring(apps: monitor.ignoredApps)
        let started = RecordingApps.started(before: previous, after: now)
        let recording = RecordingApps.started(before: Snapshot(), after: now)
        checked.formIntersection(recording)
        previous = now
        for app in started where checked.insert(app).inserted {
            Task {
                try? await Task.sleep(for: Self.settle)
                check(app)
            }
        }
    }

    private func check(_ app: String) {
        guard Alerts.isEnabled else { return }
        monitor.refresh(force: true)
        let snapshot = monitor.snapshot
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
