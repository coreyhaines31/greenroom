import ServiceManagement

enum LoginItem {
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
}
