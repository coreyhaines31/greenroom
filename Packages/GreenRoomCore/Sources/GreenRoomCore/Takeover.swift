import Foundation

/// "Keep my setup": when a device that just connected (AirPods out of the case, an iPhone
/// nearby) takes over the mic or the sound, switch back to the setup's device. A device you
/// picked yourself is never switched away from, because it didn't just connect.
public struct Takeover: Sendable, Equatable {
    public let kind: DeviceKind
    /// The device that took over.
    public let intruder: Device
    /// The setup's device to switch back to.
    public let restore: Device

    /// How soon after connecting a device's takeover counts as automatic.
    public static let window: TimeInterval = 15

    /// - Parameters:
    ///   - events: the new timeline events from this change.
    ///   - timeline: the whole timeline, to find when each device connected.
    ///   - exempt: devices you chose to keep, by ID.
    public static func detect(
        events: [DeviceHistory.Event], timeline: [DeviceHistory.Event], setup: Setup?, snapshot: Snapshot,
        exempt: Set<String>
    ) -> [Takeover] {
        guard let setup else { return [] }
        return events.compactMap { event in
            let intruder = event.device
            guard event.change == .selected, intruder.kind != .camera, !exempt.contains(intruder.id),
                  let expected = setup.devices[intruder.kind], expected.id != intruder.id,
                  let restore = snapshot.device(expected.id, kind: expected.kind),
                  snapshot.active(intruder.kind)?.id == intruder.id else { return nil }
            let justConnected = timeline.contains { other in
                other.change == .connected && other.device.id == intruder.id
                    && event.time.timeIntervalSince(other.time) >= 0
                    && event.time.timeIntervalSince(other.time) <= window
            }
            return justConnected ? Takeover(kind: intruder.kind, intruder: intruder, restore: restore) : nil
        }
    }
}
