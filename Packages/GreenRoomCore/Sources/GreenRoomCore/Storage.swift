import Foundation
import os

/// Where the app keeps its setup and history, shared with the `greenroom` command.
public enum Storage {
    public static let defaultsDomain = "com.greenroomformac.GreenRoom"
    /// 1.0 and 1.1 kept one setup here; it becomes the first entry of `setups`.
    static let setupKey = "setup"
    static let setupsKey = "setups"

    public static var historyURL: URL {
        URL.applicationSupportDirectory.appending(path: "Green Room/history.json")
    }

    static let log = Logger(subsystem: defaultsDomain, category: "Storage")

    /// No file yet means no history. A file that won't decode is moved aside first, so the next
    /// save can't overwrite it. Only the app repairs; the read-only command passes `repair: false`.
    public static func loadHistory(from url: URL = historyURL, now: Date = .now, repair: Bool = true) -> DeviceHistory {
        guard FileManager.default.fileExists(atPath: url.path) else { return DeviceHistory() }
        if let data = try? Data(contentsOf: url),
           let history = try? JSONDecoder().decode(DeviceHistory.self, from: data) {
            return history
        }
        guard repair else { return DeviceHistory() }
        let backup = url.deletingLastPathComponent().appending(path: "\(url.lastPathComponent).corrupt-\(stamp(now))")
        do {
            try FileManager.default.moveItem(at: url, to: backup)
            log.error("History didn't load. Moved it to \(backup.path, privacy: .public) and started fresh.")
        } catch {
            log.error("History didn't load or move aside: \(error.localizedDescription, privacy: .public)")
        }
        return DeviceHistory()
    }

    static func stamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.dateFormat = "yyyyMMdd'T'HHmmss'Z'"
        return formatter.string(from: date)
    }

    public static func saveHistory(_ history: DeviceHistory) {
        guard let data = try? JSONEncoder().encode(history) else { return }
        let folder = historyURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try? data.write(to: historyURL, options: .atomic)
    }

    /// The app passes `.standard`; the command reads the app's domain.
    /// Setups that won't decode are kept under `setups.corrupt-<time>`, so the next save can't lose them.
    /// Only the app repairs; the read-only command passes `repair: false`.
    public static func loadSetups(_ defaults: UserDefaults, now: Date = .now, repair: Bool = true) -> [Setup] {
        if let data = defaults.data(forKey: setupsKey) {
            if let setups = try? JSONDecoder().decode([Setup].self, from: data) { return setups }
            guard repair else { return [] }
            let backupKey = "\(setupsKey).corrupt-\(stamp(now))"
            defaults.set(data, forKey: backupKey)
            defaults.removeObject(forKey: setupsKey)
            log.error("Setups didn't load. Kept them under \(backupKey, privacy: .public) and started fresh.")
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
