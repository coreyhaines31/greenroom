import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let monitor = DeviceMonitor()
    private lazy var checks = Checks(monitor: monitor)
    private lazy var windows = Windows(monitor: monitor)
    private lazy var alerts = Alerts(monitor: monitor)
    private let updater = Updater()
    private var statusItemController: StatusItemController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        monitor.start()
        alerts.start()
        monitor.onEvents = { [weak self] events in self?.alerts.devicesChanged(events) }
        statusItemController = StatusItemController(
            monitor: monitor, checks: checks, windows: windows, updater: updater
        )
        #if DEBUG
        // Opens the panel on launch, for screenshots and testing without clicking.
        if CommandLine.arguments.contains("--open-panel") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) { self.statusItemController?.toggle(pinned: true) }
        }
        if let index = CommandLine.arguments.firstIndex(of: "--self-test"), index + 1 < CommandLine.arguments.count {
            SelfTest.run(monitor: monitor, writingTo: CommandLine.arguments[index + 1])
        }
        if CommandLine.arguments.contains("--open-history") {
            windows.showHistory()
        }
        if let index = CommandLine.arguments.firstIndex(of: "--snapshot"), index + 1 < CommandLine.arguments.count {
            let path = CommandLine.arguments[index + 1]
            DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
                self.statusItemController?.writeSnapshot(to: path)
                self.windows.writeHistorySnapshot(to: path.replacingOccurrences(of: ".png", with: "-history.png"))
            }
        }
        #endif
    }

    func applicationWillTerminate(_ notification: Notification) {
        checks.stop()
        monitor.stop()
    }
}
