import Carbon.HIToolbox
import Foundation

/// ⌃⌥⌘G opens the panel from anywhere, so you can check yourself mid-call without finding the
/// icon. Carbon's hot key API is still the way to get a global shortcut without accessibility
/// permission.
@MainActor
final class HotKey {
    private var hotKey: EventHotKeyRef?
    private var handler: EventHandlerRef?
    private let action: () -> Void

    /// The C callback can't capture anything, so it finds the action here.
    private static var current: HotKey?

    static let enabledKey = "hotKeyEnabled"
    static let label = "⌃⌥⌘G"

    static var isEnabled: Bool {
        get { UserDefaults.standard.object(forKey: enabledKey) as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: enabledKey) }
    }

    init(action: @escaping () -> Void) {
        self.action = action
    }

    func apply() {
        if Self.isEnabled {
            register()
        } else {
            unregister()
        }
    }

    private func register() {
        guard hotKey == nil else { return }
        Self.current = self
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, _, _ in
            DispatchQueue.main.async { MainActor.assumeIsolated { HotKey.current?.action() } }
            return noErr
        }, 1, &spec, nil, &handler)
        // "GrRm"
        let id = EventHotKeyID(signature: OSType(0x4772_526D), id: 1)
        RegisterEventHotKey(
            UInt32(kVK_ANSI_G), UInt32(controlKey | optionKey | cmdKey), id, GetApplicationEventTarget(), 0, &hotKey
        )
    }

    private func unregister() {
        if let hotKey { UnregisterEventHotKey(hotKey) }
        if let handler { RemoveEventHandler(handler) }
        hotKey = nil
        handler = nil
    }
}
