import Foundation

/// Your order for each kind of device, so Green Room can switch to the best one that's plugged
/// in when devices come and go. Keyed by device ID, so the order survives reconnects.
public struct DevicePriorities: Codable, Sendable, Equatable {
    public var order: [DeviceKind: [String]]

    static let key = "devicePriorities"

    public init(order: [DeviceKind: [String]] = [:]) {
        self.order = order
    }

    /// Your order first, then devices you haven't placed yet: wired gear you plugged in on
    /// purpose, then the Mac's own, then headsets and the iPhone that tend to grab the default.
    public func ranked(_ devices: [Device], kind: DeviceKind) -> [Device] {
        let ids = order[kind] ?? []
        let placed = ids.compactMap { id in devices.first { $0.id == id } }
        let rest = devices.filter { !ids.contains($0.id) }.enumerated()
            .sorted { (Self.rank($0.element.transport), $0.offset) < (Self.rank($1.element.transport), $1.offset) }
            .map(\.element)
        return placed + rest
    }

    /// Fills in the shown order for any kind you haven't ordered, so turning priority on does
    /// what the numbered list says.
    public mutating func adopt(_ devices: [Device], kind: DeviceKind) {
        guard order[kind] == nil, !devices.isEmpty else { return }
        order[kind] = ranked(devices, kind: kind).map(\.id)
    }

    static func rank(_ transport: Transport) -> Int {
        switch transport {
        case .usb, .thunderbolt, .external, .display: 0
        case .builtIn: 1
        case .virtual, .aggregate, .other: 2
        case .bluetooth, .airPlay: 3
        case .continuity: 4
        }
    }

    /// Moves a device up (negative) or down a step. The order shown becomes your order.
    public mutating func move(_ device: Device, by offset: Int, among devices: [Device]) {
        var ids = ranked(devices, kind: device.kind).map(\.id)
        guard let from = ids.firstIndex(of: device.id), ids.indices.contains(from + offset) else { return }
        ids.swapAt(from, from + offset)
        // Devices that aren't listed right now keep their place at the end.
        order[device.kind] = ids + (order[device.kind] ?? []).filter { !ids.contains($0) }
    }

    /// The highest device you've placed that's connected. Nil until you've ordered this kind,
    /// so turning priority on never switches to a device you didn't put in the list.
    public func best(_ kind: DeviceKind, in snapshot: Snapshot) -> Device? {
        let connected = snapshot.devices(kind)
        for id in order[kind] ?? [] {
            if let device = connected.first(where: { $0.id == id }) { return device }
        }
        return nil
    }

    public static func load(_ defaults: UserDefaults) -> DevicePriorities {
        defaults.data(forKey: key).flatMap { try? JSONDecoder().decode(DevicePriorities.self, from: $0) }
            ?? DevicePriorities()
    }

    public func save(_ defaults: UserDefaults) {
        guard let data = try? JSONEncoder().encode(self) else { return }
        defaults.set(data, forKey: Self.key)
    }
}
