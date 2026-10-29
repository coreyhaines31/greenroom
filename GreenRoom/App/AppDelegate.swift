import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let monitor = DeviceMonitor()
    private lazy var checks = Checks(monitor: monitor)
    private lazy var windows = Windows(monitor: monitor)
    private lazy var alerts = Alerts(monitor: monitor)
    private lazy var keepSetup = KeepSetup(monitor: monitor, alerts: alerts)
    private lazy var usePriority = UsePriority(monitor: monitor)
    private lazy var callWatcher = CallWatcher(monitor: monitor, alerts: alerts)
    private lazy var recordingWatcher = RecordingWatcher(monitor: monitor, alerts: alerts)
    private lazy var holdCalls = HoldCalls(monitor: monitor, calendar: callWatcher, checks: checks)
    private lazy var micWatch = MicWatch(monitor: monitor)
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
            self?.usePriority.devicesChanged(events)
            self?.alerts.devicesChanged(events)
            self?.recordingWatcher.devicesChanged()
            self?.holdCalls.check()
        }
        callWatcher.start()
        holdCalls.start()
        micWatch.start()
        statusItemController = StatusItemController(
            monitor: monitor, checks: checks, windows: windows, updater: updater
        )
        hotKey.apply()
        windows.callWatcher = callWatcher
        windows.checks = checks
        windows.updater = updater
        windows.hotKey = hotKey
        windows.holdCalls = holdCalls
        windows.micWatch = micWatch
        windows.showWelcomeIfNew(isNewUser: isNewUser)
        #if !DEBUG
        // Debug builds share the bundle id, so they'd register themselves instead of /Applications.
        LoginItem.applyDefaultOnce()
        #endif
        #if DEBUG
        handleDebugArguments()
        #endif
    }

    #if DEBUG
    /// Launch flags for screenshots and testing without clicking.
    private func handleDebugArguments() {
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
        if let index = arguments.firstIndex(of: "--render-monitor"), index + 1 < arguments.count {
            MonitorSample.write(to: arguments[index + 1])
        }
        if let index = arguments.firstIndex(of: "--capture-monitor"), index + 1 < arguments.count {
            LiveMonitorTest.run(monitor: monitor, writingTo: arguments[index + 1])
        }
        if CommandLine.arguments.contains("--open-record-preview") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                self.windows.showRecordPreview(on: NSScreen.main, fullScreen: false)
            }
        }
        if let index = arguments.firstIndex(of: "--snapshot-popover"), index + 1 < arguments.count {
            DispatchQueue.main.asyncAfter(deadline: .now() + 4) { Self.writePopover(to: arguments[index + 1]) }
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
                self.windows.writeRecordPreviewSnapshot(to: path.replacingOccurrences(of: ".png", with: "-preview.png"))
            }
        }
    }

    /// The open popover, such as the record preview's Guides or Monitor (with
    /// `--open-guides-popover` or `--open-monitor-popover`). It's its own window, so the
    /// preview snapshot leaves it out.
    private static func writePopover(to path: String) {
        guard let window = NSApp.windows.first(where: { String(describing: type(of: $0)).contains("Popover") }),
              let view = window.contentView?.superview ?? window.contentView, let layer = view.layer,
              let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds),
              let context = NSGraphicsContext(bitmapImageRep: rep) else { return }
        layer.render(in: context.cgContext)
        try? rep.representation(using: .png, properties: [:])?.write(to: URL(fileURLWithPath: path))
    }
    #endif

    func applicationWillTerminate(_ notification: Notification) {
        holdCalls.stop()
        micWatch.stop()
        checks.stop()
        monitor.stop()
    }
}
