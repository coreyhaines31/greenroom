import Foundation

/// What Green Room has seen: every device, the days it was connected, and a timeline of
/// plug-ins, unplugs, and switches. Stored as one JSON file.
public struct DeviceHistory: Codable, Sendable, Equatable {
    public struct Record: Codable, Sendable, Equatable {
        public var device: Device
        public var firstSeen: Date
        public var lastSeen: Date
        /// Days it was connected, as `yyyy-MM-dd`, newest last.
        public var days: [String]
        /// Days it was the one in use (the system default, or the suggested camera). Optional so
        /// history saved by 1.0 still loads.
        public var activeDays: [String]?
    }

    public enum Change: String, Codable, Sendable { case connected, disconnected, selected }

    public struct Event: Codable, Sendable, Equatable, Identifiable {
        public let time: Date
        public let change: Change
        public let device: Device

        public var id: String { "\(time.timeIntervalSince1970)-\(change.rawValue)-\(DeviceHistory.key(device))" }
    }

    public private(set) var records: [String: Record] = [:]
    public private(set) var events: [Event] = []
    /// Days Green Room was running, as `yyyy-MM-dd`.
    public private(set) var appDays: [String] = []
    private var present: Set<String>?
    private var active: [DeviceKind: String] = [:]

    static let maxEvents = 1000
    static let maxDays = 60
    static let usualWindow = 14

    public init() {}

    static func key(_ device: Device) -> String { "\(device.kind.rawValue):\(device.id)" }

    public func record(for device: Device) -> Record? { records[Self.key(device)] }

    /// Folds in the latest snapshot. Returns true when anything worth saving changed.
    @discardableResult
    public mutating func update(_ snapshot: Snapshot, now: Date, calendar: Calendar = .current) -> Bool {
        let before = self
        let today = Self.day(now, calendar)
        Self.append(today, to: &appDays)

        let devices = DeviceKind.allCases.flatMap(snapshot.devices)
        let keys = Set(devices.map(Self.key))
        for device in devices {
            let key = Self.key(device)
            var record = records[key] ?? Record(device: device, firstSeen: now, lastSeen: now, days: [])
            record.device = device
            record.lastSeen = now
            Self.append(today, to: &record.days)
            if snapshot.active(device.kind)?.id == device.id {
                var activeDays = record.activeDays ?? []
                Self.append(today, to: &activeDays)
                record.activeDays = activeDays
            }
            records[key] = record
            // The first run has nothing to compare against, so it records no events.
            if let present, !present.contains(key) {
                events.append(Event(time: now, change: .connected, device: device))
            }
        }
        for key in (present ?? []).subtracting(keys).sorted() {
            if let record = records[key] {
                events.append(Event(time: now, change: .disconnected, device: record.device))
            }
        }
        for kind in [DeviceKind.microphone, .speaker] {
            let current = snapshot.active(kind)
            if present != nil, let current, active[kind] != current.id, active[kind] != nil {
                events.append(Event(time: now, change: .selected, device: current))
            }
            active[kind] = current?.id
        }
        present = keys
        if events.count > Self.maxEvents { events.removeFirst(events.count - Self.maxEvents) }
        return self != before
    }

    /// Connected on at least 3 of the last 14 days, or on every day Green Room has run if
    /// that's fewer. A device you stop using drops off after two weeks on its own.
    public func isUsual(_ record: Record, now: Date, calendar: Calendar = .current) -> Bool {
        let window = Self.window(now: now, calendar: calendar)
        let seen = record.days.filter(window.contains).count
        let ran = appDays.filter(window.contains).count
        return seen > 0 && seen >= min(3, ran)
    }

    /// Days in the last two weeks this device was connected.
    public func recentDays(_ record: Record, now: Date, calendar: Calendar = .current) -> Int {
        let window = Self.window(now: now, calendar: calendar)
        return record.days.filter(window.contains).count
    }

    /// Days in the last two weeks this device was the one in use.
    public func recentActiveDays(_ record: Record, now: Date, calendar: Calendar = .current) -> Int {
        let window = Self.window(now: now, calendar: calendar)
        return (record.activeDays ?? []).filter(window.contains).count
    }

    static func window(now: Date, calendar: Calendar) -> Set<String> {
        Set((0..<usualWindow).compactMap { offset in
            calendar.date(byAdding: .day, value: -offset, to: now).map { day($0, calendar) }
        })
    }

    /// Devices that are usually connected but aren't right now, most recently seen first.
    public func missingUsual(_ snapshot: Snapshot, now: Date, calendar: Calendar = .current) -> [Record] {
        records.values
            .filter { !snapshot.contains($0.device.id, kind: $0.device.kind) }
            .filter { isUsual($0, now: now, calendar: calendar) }
            .sorted { $0.lastSeen > $1.lastSeen }
    }

    static func day(_ date: Date, _ calendar: Calendar) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }

    static func append(_ day: String, to days: inout [String]) {
        guard days.last != day else { return }
        days.append(day)
        if days.count > maxDays { days.removeFirst(days.count - maxDays) }
    }
}
