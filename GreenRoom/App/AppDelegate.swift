import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let monitor = DeviceMonitor()
    private lazy var checks = Checks(monitor: monitor)
    private lazy var windows = Windows(monitor: monitor)
    private lazy var alerts = Alerts(monitor: monitor)
    private lazy var keepSetup = KeepSetup(monitor: monitor, alerts: alerts)
    private lazy var callWatcher = CallWatcher(monitor: monitor, alerts: alerts)
    private lazy var recordingWatcher = RecordingWatcher(monitor: monitor, alerts: alerts)
    private let updater = Updater()
    private var statusItemController: StatusItemController?
    private lazy var hotKey = HotKey { [weak self] in self?.statusItemController?.toggle(pinned: false) }

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Before the first refresh records today: no history and no setups means a new install.
        let isNewUser = monitor.history.appDays.isEmpty && monitor.setups.isEmpty
        monitor.start()
        alerts.start()
        monitor.onEvents = { [weak self] events in
            // Switch back first, so the alerts see the fixed state.
            self?.keepSetup.devicesChanged(events)
            self?.alerts.devicesChanged(events)
            self?.recordingWatcher.devicesChanged()
        }
        callWatcher.start()
        statusItemController = StatusItemController(
            monitor: monitor, checks: checks, windows: windows, updater: updater
        )
        hotKey.apply()
        windows.callWatcher = callWatcher
        windows.updater = updater
        windows.hotKey = hotKey
        windows.showWelcomeIfNew(isNewUser: isNewUser)
        #if DEBUG
        // Opens the panel on launch, for screenshots and testing without clicking.
        if CommandLine.arguments.contains("--open-panel") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) { self.statusItemController?.toggle(pinned: true) }
        }
        if let index = CommandLine.arguments.firstIndex(of: "--self-test"), index + 1 < CommandLine.arguments.count {
            SelfTest.run(monitor: monitor, writingTo: CommandLine.arguments[index + 1])
        }
        if CommandLine.arguments.contains("--open-settings") {
            windows.showSettings()
        }
        let arguments = CommandLine.arguments
        if let index = arguments.firstIndex(of: "--render-compare"), index + 1 < arguments.count {
            CompareSample.write(to: arguments[index + 1])
        }
        if CommandLine.arguments.contains("--open-history") {
            windows.showHistory()
        }
        if let index = CommandLine.arguments.firstIndex(of: "--snapshot"), index + 1 < CommandLine.arguments.count {
            let path = CommandLine.arguments[index + 1]
            DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
                self.statusItemController?.writeSnapshot(to: path)
                self.windows.writeHistorySnapshot(to: path.replacingOccurrences(of: ".png", with: "-history.png"))
                self.windows.writeWelcomeSnapshot(to: path.replacingOccurrences(of: ".png", with: "-welcome.png"))
                self.windows.writeSettingsSnapshot(to: path.replacingOccurrences(of: ".png", with: "-settings.png"))
            }
        }
        #endif
    }

    func applicationWillTerminate(_ notification: Notification) {
        checks.stop()
        monitor.stop()
    }
}
