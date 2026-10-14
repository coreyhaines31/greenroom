import Foundation

/// A wired device that keeps dropping out and coming straight back: the signature of a worn
/// cable, a loose port, or an underpowered hub. Unplugging something on purpose doesn't count,
/// because it stays unplugged for a while.
public struct FlakyDevice: Sendable, Equatable {
    public let device: Device
    public let blips: Int

    public var message: String { "\(device.name) dropped out and came back \(blips) times this week" }

    public var advice: String {
        "Try another cable or port, or plug it straight into your Mac instead of a hub."
    }

    /// Three blips in a week is more than chance.
    public static let threshold = 3
    static let window: TimeInterval = 7 * 24 * 3600
    /// Back within two minutes means it dropped, not that someone unplugged it.
    static let blipLength: TimeInterval = 120
    /// Several devices blipping together is sleep, wake, or a dock, not one bad cable.
    static let together: TimeInterval = 5

    public static func find(in history: DeviceHistory, now: Date) -> [FlakyDevice] {
        let events = history.events.filter { now.timeIntervalSince($0.time) <= window }
        let drops = events.enumerated().filter { _, event in
            event.change == .disconnected && DeviceHistory.wired.contains(event.device.transport)
        }
        // Each drop that comes back quickly, as (name, time).
        let blips: [(device: Device, time: Date)] = drops.compactMap { index, drop in
            let back = events[(index + 1)...].contains { later in
                later.change == .connected && later.device.id == drop.device.id
                    && later.time.timeIntervalSince(drop.time) <= blipLength
            }
            return back ? (drop.device, drop.time) : nil
        }
        var counts: [String: (device: Device, times: [Date])] = [:]
        for blip in blips {
            let others = Set(blips.filter { abs($0.time.timeIntervalSince(blip.time)) <= together }.map(\.device.name))
            guard others.count < 3 else { continue }
            // A USB headset is a mic and a speaker; one drop is one blip.
            var entry = counts[blip.device.name] ?? (blip.device, [])
            if !entry.times.contains(where: { abs($0.timeIntervalSince(blip.time)) <= together }) {
                entry.times.append(blip.time)
            }
            counts[blip.device.name] = entry
        }
        return counts.values
            .map { FlakyDevice(device: $0.device, blips: $0.times.count) }
            .filter { $0.blips >= threshold }
            .sorted { $0.blips > $1.blips }
    }
}
