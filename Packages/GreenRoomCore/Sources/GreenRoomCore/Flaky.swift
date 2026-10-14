import Foundation

/// A device that keeps dropping out: usually a worn cable, a loose port, or an underpowered hub.
public struct FlakyDevice: Sendable, Equatable {
    public let device: Device
    public let drops: Int

    public var message: String { "\(device.name) disconnected \(drops) times this week" }

    public var advice: String {
        switch device.transport {
        case .bluetooth: "Keep it charged and closer to your Mac, or forget and re-pair it in Bluetooth settings."
        case .usb, .external: "Try another cable or port, or plug it straight into your Mac instead of a hub."
        default: "Check its connection, or try another port."
        }
    }

    /// Five drops in a week is more than a few deliberate unplugs.
    public static let threshold = 5
    static let window: TimeInterval = 7 * 24 * 3600
    /// Unplugging a whole dock drops everything on it at once; that's one decision, not a fault.
    static let dockGap: TimeInterval = 5

    /// Counts drops in the last week, skipping ones that happened with several other devices at
    /// the same moment, and leaving out a mic and speaker that are the same headset twice.
    public static func find(in history: DeviceHistory, now: Date) -> [FlakyDevice] {
        let recent = history.events.filter {
            $0.change == .disconnected && now.timeIntervalSince($0.time) <= window
        }
        var drops: [String: (device: Device, count: Int)] = [:]
        for event in recent {
            let together = recent.filter { abs($0.time.timeIntervalSince(event.time)) <= dockGap }
            let others = Set(together.map(\.device.name)).subtracting([event.device.name])
            guard others.count < 2 else { continue }
            let key = event.device.name
            drops[key] = (event.device, (drops[key]?.count ?? 0) + 1)
        }
        // A headset is a mic and a speaker; count each drop once by halving its pair of events.
        return drops.values
            .map { entry in
                let pair = recent.contains {
                    $0.device.name == entry.device.name && $0.device.kind != entry.device.kind
                }
                return FlakyDevice(device: entry.device, drops: pair ? (entry.count + 1) / 2 : entry.count)
            }
            .filter { $0.drops >= threshold }
            .sorted { $0.drops > $1.drops }
    }
}
