import Foundation

/// Where the app keeps its setup and history, shared with the `greenroom` command.
public enum Storage {
    public static let defaultsDomain = "com.greenroomformac.GreenRoom"
    static let setupKey = "setup"

    public static var historyURL: URL {
        URL.applicationSupportDirectory.appending(path: "Green Room/history.json")
    }

    public static func loadHistory() -> DeviceHistory {
        (try? Data(contentsOf: historyURL)).flatMap { try? JSONDecoder().decode(DeviceHistory.self, from: $0) }
            ?? DeviceHistory()
    }

    public static func saveHistory(_ history: DeviceHistory) {
        guard let data = try? JSONEncoder().encode(history) else { return }
        let folder = historyURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try? data.write(to: historyURL, options: .atomic)
    }

    /// The app passes `.standard`; the command reads the app's domain.
    public static func loadSetup(_ defaults: UserDefaults) -> Setup? {
        defaults.data(forKey: setupKey).flatMap { try? JSONDecoder().decode(Setup.self, from: $0) }
    }

    public static func saveSetup(_ setup: Setup?, _ defaults: UserDefaults) {
        if let setup, let data = try? JSONEncoder().encode(setup) {
            defaults.set(data, forKey: setupKey)
        } else {
            defaults.removeObject(forKey: setupKey)
        }
    }
}
