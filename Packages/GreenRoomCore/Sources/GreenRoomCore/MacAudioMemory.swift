import Foundation

/// macOS remembers every USB audio device it has ever used, in Core Audio's settings file.
/// That gives Green Room a history from day one, before it has recorded any of its own.
public enum MacAudioMemory {
    public static let settingsURL = URL(
        fileURLWithPath: "/Library/Preferences/Audio/com.apple.audio.SystemSettings.plist"
    )

    public struct Remembered: Sendable, Equatable {
        public let id: String
        public let name: String
    }

    public static func remembered() -> [Remembered] {
        (try? Data(contentsOf: settingsURL)).map(remembered(fromPlist:)) ?? []
    }

    /// Keys look like `device.AppleUSBAudioEngine:<maker>:<product>:<serial>:<port>`, where
    /// everything after `device.` is the Core Audio UID. Other device types don't carry a
    /// readable name, so they're skipped.
    static func remembered(fromPlist data: Data) -> [Remembered] {
        guard let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any] else {
            return []
        }
        var seen = Set<String>()
        return plist.keys.sorted().compactMap { key -> Remembered? in
            guard key.hasPrefix("device.AppleUSBAudioEngine:") else { return nil }
            let id = String(key.dropFirst("device.".count))
            let parts = id.split(separator: ":", omittingEmptySubsequences: false)
            guard parts.count >= 3 else { return nil }
            let name = String(parts[2]).trimmingCharacters(in: .whitespaces)
            // The same product shows up once per USB port it has been in.
            guard !name.isEmpty, seen.insert(name).inserted else { return nil }
            return Remembered(id: id, name: name)
        }
    }
}
