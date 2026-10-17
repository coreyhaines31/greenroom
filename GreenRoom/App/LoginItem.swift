import Foundation
import ServiceManagement

enum LoginItem {
    static let appliedDefaultKey = "appliedLaunchAtLoginDefault"

    static var isEnabled: Bool { SMAppService.mainApp.status == .enabled }

    /// Returns whether it's on afterwards, since macOS can refuse.
    static func set(_ enabled: Bool) -> Bool {
        if enabled {
            try? SMAppService.mainApp.register()
        } else {
            try? SMAppService.mainApp.unregister()
        }
        return isEnabled
    }

    /// On by default, once, so turning it off in Settings or the welcome sticks.
    static func applyDefaultOnce() {
        guard !UserDefaults.standard.bool(forKey: appliedDefaultKey) else { return }
        UserDefaults.standard.set(true, forKey: appliedDefaultKey)
        _ = set(true)
    }
}
