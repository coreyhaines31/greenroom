import AppKit

/// Once access is refused, macOS won't ask again, so the fix is the right pane in System Settings.
enum PrivacySettings {
    enum Pane: String {
        case camera = "Privacy_Camera"
        case microphone = "Privacy_Microphone"
    }

    static func open(_ pane: Pane) {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?\(pane.rawValue)") else {
            return
        }
        NSWorkspace.shared.open(url)
    }
}
