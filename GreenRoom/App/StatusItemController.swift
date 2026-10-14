import AppKit
import GreenRoomCore
import SwiftUI

/// Owns the menu bar item: a plain `NSStatusItem` with an `autosaveName`, so macOS can
/// Cmd-drag it and remember where it goes. Clicking it opens the panel in a popover.
@MainActor
final class StatusItemController: NSObject, NSPopoverDelegate {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let popover = NSPopover()
    private let monitor: DeviceMonitor
    private let checks: Checks

    private let windows: Windows

    init(monitor: DeviceMonitor, checks: Checks, windows: Windows, updater: Updater, callWatcher: CallWatcher) {
        self.monitor = monitor
        self.checks = checks
        self.windows = windows
        super.init()

        statusItem.autosaveName = "GreenRoomStatusItem"
        statusItem.button?.target = self
        statusItem.button?.action = #selector(statusItemClicked)
        statusItem.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])

        popover.behavior = .transient
        popover.delegate = self
        let panel = PanelView(
            monitor: monitor, checks: checks, updater: updater, callWatcher: callWatcher
        ) { [weak self] in
            self?.popover.performClose(nil)
            self?.windows.showHistory()
        }
        let hosting = NSHostingController(rootView: panel)
        // The panel's height changes while it's open (permission prompts, the preview, a missing
        // device). Tracking it keeps the popover anchored under the menu bar instead of growing
        // up past the top of the screen.
        hosting.sizingOptions = .preferredContentSize
        popover.contentViewController = hosting

        monitor.onChange = { [weak self] in self?.refreshButton() }
        refreshButton()
    }

    /// Click opens the panel. Right-click or Control-click opens a quick menu that switches
    /// devices without starting the camera.
    @objc private func statusItemClicked() {
        let event = NSApp.currentEvent
        if event?.type == .rightMouseUp || event?.modifierFlags.contains(.control) == true {
            showQuickMenu()
        } else {
            toggle(pinned: false)
        }
    }

    private func showQuickMenu() {
        if popover.isShown { popover.performClose(nil) }
        monitor.refresh(force: true)
        statusItem.menu = QuickMenu.make(monitor: monitor) { [weak self] in self?.toggle(pinned: false) }
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }

    /// `pinned` keeps the panel open when another app takes focus (debug screenshots).
    func toggle(pinned: Bool) {
        popover.behavior = pinned ? .applicationDefined : .transient
        if popover.isShown {
            popover.performClose(nil)
        } else if let button = statusItem.button {
            monitor.refresh(force: true)
            checks.start()
            if let view = popover.contentViewController?.view {
                view.layoutSubtreeIfNeeded()
                popover.contentSize = view.fittingSize
            }
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }

    #if DEBUG
    /// Draws the open panel to a PNG. The camera preview layer draws black here.
    func writeSnapshot(to path: String) {
        guard let view = popover.contentViewController?.view,
              let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { return }
        view.cacheDisplay(in: view.bounds, to: rep)
        try? rep.representation(using: .png, properties: [:])?.write(to: URL(fileURLWithPath: path))
    }
    #endif

    func popoverDidClose(_ notification: Notification) {
        checks.stop()
    }

    private func refreshButton() {
        let problems = monitor.advisories.map(\.title) + {
            if case .notReady(let issues) = monitor.readiness { return issues.map(\.message) }
            return []
        }()
        let (symbol, label): (String, String) = if !problems.isEmpty {
            ("exclamationmark.triangle.fill", problems.joined(separator: ". "))
        } else if monitor.readiness == .ready {
            ("web.camera.fill", "Green Room: ready")
        } else {
            ("web.camera", "Green Room")
        }
        statusItem.button?.image = NSImage(systemSymbolName: symbol, accessibilityDescription: label)
        statusItem.button?.setAccessibilityLabel(label)
        statusItem.button?.toolTip = label
    }
}
