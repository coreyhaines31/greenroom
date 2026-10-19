import AppKit
import SwiftUI

/// The app's one regular window. A menu bar app has no Dock icon, so showing a window
/// means activating the app first.
@MainActor
final class Windows {
    private let monitor: DeviceMonitor
    private var history: NSWindow?
    private var welcome: NSWindow?
    private var settings: NSWindow?
    private var recordPreview: NSWindow?
    var checks: Checks?
    var callWatcher: CallWatcher?
    var updater: Updater?
    var hotKey: HotKey?

    func showSettings() {
        if settings == nil, let callWatcher, let updater, let hotKey {
            let view = SettingsView(monitor: monitor, updater: updater, callWatcher: callWatcher, hotKey: hotKey)
            let window = NSWindow(contentViewController: NSHostingController(rootView: view))
            window.title = "Green Room Settings"
            window.styleMask.remove(.resizable)
            window.isReleasedWhenClosed = false
            window.center()
            settings = window
        }
        NSApp.activate()
        settings?.makeKeyAndOrderFront(nil)
    }

    static let seenWelcomeKey = "hasSeenWelcome"

    init(monitor: DeviceMonitor) {
        self.monitor = monitor
    }

    /// Once, on a new install. People who already used Green Room have their settings, so it
    /// would only get in the way. Marked seen when shown, so closing it any way counts.
    func showWelcomeIfNew(isNewUser: Bool) {
        guard !UserDefaults.standard.bool(forKey: Self.seenWelcomeKey), let callWatcher else { return }
        UserDefaults.standard.set(true, forKey: Self.seenWelcomeKey)
        guard isNewUser else { return }
        let view = WelcomeView(monitor: monitor, callWatcher: callWatcher) { [weak self] in
            self?.welcome?.close()
            self?.welcome = nil
        }
        let window = NSWindow(contentViewController: NSHostingController(rootView: view))
        window.title = "Welcome"
        window.styleMask.remove(.resizable)
        window.isReleasedWhenClosed = false
        window.center()
        welcome = window
        monitor.refresh(force: true)
        NSApp.activate()
        window.makeKeyAndOrderFront(nil)
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
        monitor.refresh(force: true)
        NSApp.activate()
        history?.makeKeyAndOrderFront(nil)
    }

    /// While it's open, the live checks keep running after the panel closes.
    var isRecordPreviewOpen: Bool { recordPreview?.isVisible == true }

    /// Full screen on the display the panel was on, like a teleprompter.
    func showRecordPreview(on screen: NSScreen?, fullScreen: Bool = true) {
        guard let checks else { return }
        if recordPreview == nil {
            let view = RecordPreviewView(monitor: monitor, checks: checks) { [weak self] in
                self?.recordPreview?.close()
            }
            let window = NSWindow(contentViewController: NSHostingController(rootView: view))
            window.title = "Record Preview"
            window.styleMask.insert(.resizable)
            window.collectionBehavior.insert(.fullScreenPrimary)
            window.isReleasedWhenClosed = false
            NotificationCenter.default.addObserver(
                forName: NSWindow.willCloseNotification, object: window, queue: .main
            ) { [weak checks] _ in
                MainActor.assumeIsolated { checks?.stop() }
            }
            recordPreview = window
        }
        guard let window = recordPreview else { return }
        if !window.isVisible, let screen {
            window.setFrame(screen.visibleFrame, display: false)
        }
        monitor.refresh(force: true)
        checks.start()
        NSApp.activate()
        window.makeKeyAndOrderFront(nil)
        if fullScreen, !window.styleMask.contains(.fullScreen) {
            window.toggleFullScreen(nil)
        }
    }

    #if DEBUG
    func writeRecordPreviewSnapshot(to path: String) {
        guard let view = recordPreview?.contentView,
              let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { return }
        view.cacheDisplay(in: view.bounds, to: rep)
        try? rep.representation(using: .png, properties: [:])?.write(to: URL(fileURLWithPath: path))
    }

    func writeSettingsSnapshot(to path: String) {
        guard let view = settings?.contentView,
              let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { return }
        view.cacheDisplay(in: view.bounds, to: rep)
        try? rep.representation(using: .png, properties: [:])?.write(to: URL(fileURLWithPath: path))
    }

    func writeWelcomeSnapshot(to path: String) {
        guard let view = welcome?.contentView,
              let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { return }
        view.cacheDisplay(in: view.bounds, to: rep)
        try? rep.representation(using: .png, properties: [:])?.write(to: URL(fileURLWithPath: path))
    }

    func writeHistorySnapshot(to path: String) {
        guard let view = history?.contentView,
              let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { return }
        view.cacheDisplay(in: view.bounds, to: rep)
        try? rep.representation(using: .png, properties: [:])?.write(to: URL(fileURLWithPath: path))
    }
    #endif
}
