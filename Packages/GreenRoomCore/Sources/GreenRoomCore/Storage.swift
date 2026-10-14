import Foundation

/// Where the app keeps its setup and history, shared with the `greenroom` command.
public enum Storage {
    public static let defaultsDomain = "com.greenroomformac.GreenRoom"
    /// 1.0 and 1.1 kept one setup here; it becomes the first entry of `setups`.
    static let setupKey = "setup"
    static let setupsKey = "setups"

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
    public static func loadSetups(_ defaults: UserDefaults) -> [Setup] {
        if let data = defaults.data(forKey: setupsKey),
           let setups = try? JSONDecoder().decode([Setup].self, from: data) {
            return setups
        }
        let single = defaults.data(forKey: setupKey).flatMap { try? JSONDecoder().decode(Setup.self, from: $0) }
        return single.map { [$0] } ?? []
    }

    public static func saveSetups(_ setups: [Setup], _ defaults: UserDefaults) {
        guard let data = try? JSONEncoder().encode(setups) else { return }
        defaults.set(data, forKey: setupsKey)
        defaults.removeObject(forKey: setupKey)
    }
}
