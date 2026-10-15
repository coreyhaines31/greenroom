import Foundation

/// Names you give devices ("Lapel mic" for "USB Audio Device"), and devices you hide from the
/// pickers. Keyed by device ID, so a name survives reconnects. Shared with the `greenroom`
/// command through the app's defaults.
public struct DeviceNames: Codable, Sendable, Equatable {
    public var nicknames: [String: String]
    public var hidden: Set<String>

    static let key = "deviceNames"

    public init(nicknames: [String: String] = [:], hidden: Set<String> = []) {
        self.nicknames = nicknames
        self.hidden = hidden
    }

    /// Blank clears the name, so the device goes back to what macOS calls it.
    public mutating func setNickname(_ name: String, for id: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        nicknames[id] = trimmed.isEmpty ? nil : trimmed
    }

    public func isHidden(_ device: Device) -> Bool { hidden.contains(device.id) }

    public func apply(_ device: Device) -> Device {
        guard let nickname = nicknames[device.id] else { return device }
        return Device(id: device.id, name: nickname, kind: device.kind, transport: device.transport)
    }

    public func apply(_ snapshot: Snapshot) -> Snapshot {
        guard !nicknames.isEmpty else { return snapshot }
        var copy = snapshot
        copy.devices = snapshot.devices.mapValues { $0.map(apply) }
        copy.active = snapshot.active.mapValues(apply)
        return copy
    }

    /// Setups keep the name a device had when saved; this shows the current one instead.
    public func apply(_ setup: Setup) -> Setup {
        var copy = setup
        copy.devices = setup.devices.mapValues(apply)
        return copy
    }

    public static func load(_ defaults: UserDefaults) -> DeviceNames {
        defaults.data(forKey: key).flatMap { try? JSONDecoder().decode(DeviceNames.self, from: $0) } ?? DeviceNames()
    }

    public func save(_ defaults: UserDefaults) {
        guard let data = try? JSONEncoder().encode(self) else { return }
        defaults.set(data, forKey: Self.key)
    }
}
