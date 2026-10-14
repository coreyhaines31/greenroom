import AppKit
import SwiftUI

/// The app's one regular window. A menu bar app has no Dock icon, so showing a window
/// means activating the app first.
@MainActor
final class Windows {
    private let monitor: DeviceMonitor
    private var history: NSWindow?

    init(monitor: DeviceMonitor) {
        self.monitor = monitor
    }

    func showHistory() {
        if history == nil {
            let window = NSWindow(contentViewController: NSHostingController(rootView: HistoryView(monitor: monitor)))
            window.title = "Device History"
            window.setContentSize(NSSize(width: 520, height: 560))
            window.styleMask.insert(.resizable)
            window.isReleasedWhenClosed = false
            window.setFrameAutosaveName("History")
            history = window
        }
        monitor.refresh()
        NSApp.activate()
        history?.makeKeyAndOrderFront(nil)
    }

    #if DEBUG
    func writeHistorySnapshot(to path: String) {
        guard let view = history?.contentView,
              let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { return }
        view.cacheDisplay(in: view.bounds, to: rep)
        try? rep.representation(using: .png, properties: [:])?.write(to: URL(fileURLWithPath: path))
    }
    #endif
}
