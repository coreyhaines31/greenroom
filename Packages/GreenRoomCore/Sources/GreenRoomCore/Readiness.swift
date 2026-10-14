import Foundation

/// The devices you expect for a call or a recording, e.g. "Studio: ZV-E10 + Shure MV7 + monitors".
public struct Setup: Codable, Sendable, Equatable {
    public var name: String
    public var devices: [DeviceKind: Device]
    /// When it was last saved or applied, to break ties between setups. Optional so setups
    /// saved by 1.0 and 1.1 still load.
    public var lastUsed: Date?

    public init(name: String, devices: [DeviceKind: Device], lastUsed: Date? = nil) {
        self.name = name
        self.devices = devices
        self.lastUsed = lastUsed
    }

    /// How many of its devices are connected right now.
    public func connectedCount(in snapshot: Snapshot) -> Int {
        devices.values.filter { snapshot.contains($0.id, kind: $0.kind) }.count
    }

    /// The setup that fits what's plugged in: the most of its devices connected, then the
    /// biggest share of them, then the one used last. Plug in the dock and Desk wins; unplug
    /// it and Travel does.
    public static func bestMatch(_ setups: [Setup], snapshot: Snapshot) -> Setup? {
        setups.max { lhs, rhs in
            let left = lhs.connectedCount(in: snapshot), right = rhs.connectedCount(in: snapshot)
            if left != right { return left < right }
            let leftShare = Double(left) / Double(max(lhs.devices.count, 1))
            let rightShare = Double(right) / Double(max(rhs.devices.count, 1))
            if leftShare != rightShare { return leftShare < rightShare }
            return (lhs.lastUsed ?? .distantPast) < (rhs.lastUsed ?? .distantPast)
        }
    }

    /// Saves whatever is active right now.
    public static func current(_ snapshot: Snapshot, name: String = "My setup") -> Setup {
        Setup(name: name, devices: snapshot.active)
    }

    /// A first guess at your setup: for each kind, the device that was in use on the most recent
    /// days, even if it's unplugged right now. Built-in devices are always connected, so being in
    /// use counts first and being connected only breaks ties. Falls back to what's active.
    public static func proposed(
        history: DeviceHistory, snapshot: Snapshot, now: Date, calendar: Calendar = .current,
        name: String = "My setup"
    ) -> Setup {
        var devices = snapshot.active
        for kind in DeviceKind.allCases {
            let active = snapshot.active(kind)?.id
            // Days in use, then days connected, then whether it's in use now.
            func rank(_ record: DeviceHistory.Record) -> [Int] {
                [
                    history.recentActiveDays(record, now: now, calendar: calendar),
                    history.recentDays(record, now: now, calendar: calendar),
                    record.device.id == active ? 1 : 0
                ]
            }
            let best = history.records.values
                .filter { $0.device.kind == kind }
                .max { rank($0).lexicographicallyPrecedes(rank($1)) }
            if let best, history.recentActiveDays(best, now: now, calendar: calendar) > 0 {
                devices[kind] = snapshot.device(best.device.id, kind: kind) ?? best.device
            }
        }
        return Setup(name: name, devices: devices)
    }
}

public struct Mismatch: Sendable, Equatable {
    public enum Problem: Sendable, Equatable {
        case missing
        case notSelected(actual: Device?)
        /// An app is using a different device than your setup's, whatever the default says.
        case appUsing(app: String, actual: Device)
    }

    public let kind: DeviceKind
    public let expected: Device
    public let problem: Problem
    /// The device to make the default to fix this, when that would help.
    public let fix: Device?

    public init(kind: DeviceKind, expected: Device, problem: Problem, fix: Device? = nil) {
        self.kind = kind
        self.expected = expected
        self.problem = problem
        self.fix = fix
    }

    public var message: String {
        switch problem {
        case .missing:
            return "\(expected.name) isn't connected"
        case .notSelected(let actual?):
            let lead = kind == .speaker ? "Sound is going to" : "\(kind.title) is"
            return "\(lead) \(actual.name), not \(expected.name)"
        case .notSelected(nil):
            return "No \(kind.title.lowercased()) selected"
        case .appUsing(let app, let actual):
            return "\(app) is using \(actual.name), not \(expected.name)"
        }
    }

    /// What to do when there's no one-click fix, or what the fix button doesn't cover.
    public var advice: String? {
        switch problem {
        case .appUsing(let app, _) where fix == nil:
            return "Pick \(expected.name) in \(app)'s audio settings."
        case .appUsing(let app, _):
            return "If \(app) doesn't follow your Mac's default, pick \(expected.name) in its audio settings."
        default:
            return nil
        }
    }
}

public enum Readiness: Sendable, Equatable {
    case noSetup
    case ready
    case notReady([Mismatch])

    public static func evaluate(_ snapshot: Snapshot, setup: Setup?) -> Readiness {
        guard let setup, !setup.devices.isEmpty else { return .noSetup }
        var issues: [Mismatch] = []
        for kind in DeviceKind.allCases {
            guard let expected = setup.devices[kind] else { continue }
            if !snapshot.contains(expected.id, kind: kind) {
                issues.append(Mismatch(kind: kind, expected: expected, problem: .missing))
                continue
            }
            // Cameras only need to be connected: each call app picks its own.
            guard kind != .camera else { continue }
            let isDefault = snapshot.active(kind)?.id == expected.id
            let fix = isDefault ? nil : expected
            // What an app is really using beats what the default says.
            if let use = wrongLiveUse(snapshot, kind: kind, expected: expected),
               let actual = snapshot.device(use.deviceID, kind: kind) {
                let problem = Mismatch.Problem.appUsing(app: use.app ?? "An app", actual: actual)
                issues.append(Mismatch(kind: kind, expected: expected, problem: problem, fix: fix))
            } else if !isDefault {
                let problem = Mismatch.Problem.notSelected(actual: snapshot.active(kind))
                issues.append(Mismatch(kind: kind, expected: expected, problem: problem, fix: fix))
            }
        }
        return issues.isEmpty ? .ready : .notReady(issues)
    }

    /// An app using another real device of this kind, unless that same app also has the expected
    /// one. Virtual and aggregate devices (Zoom's screen-share audio, loopback tools) don't count.
    static func wrongLiveUse(_ snapshot: Snapshot, kind: DeviceKind, expected: Device) -> LiveUse? {
        let uses = snapshot.live.filter { $0.kind == kind }
        let appsOnExpected = Set(uses.filter { $0.deviceID == expected.id }.map(\.app))
        return uses.first { use in
            guard use.deviceID != expected.id, !appsOnExpected.contains(use.app),
                  let device = snapshot.device(use.deviceID, kind: kind) else { return false }
            return device.transport != .virtual && device.transport != .aggregate
        }
    }
}

/// Something worth knowing whether or not you've saved a setup.
public struct Advisory: Sendable, Equatable {
    public enum Kind: Sendable, Equatable {
        /// A Bluetooth headset's mic is on, so it has dropped to phone-call sound both ways.
        case callQuality
    }

    public let kind: Kind
    public let device: Device
    public let apps: [String]
    public let fix: Device?

    public var title: String { "\(device.name) is in call mode" }

    public var message: String {
        let using = apps.isEmpty ? "An app" : ListFormatter.localizedString(byJoining: apps)
        let base = "\(using) turned on its mic, so your voice and everything you hear drop to phone quality."
        guard let fix else { return base }
        return base + " Use \(fix.name) for your voice and keep the headset for listening."
    }

    /// Call mode tops out at 24 kHz; headsets play music at 44.1 kHz or more.
    static let callModeMaxRate = 24_000.0

    public static func evaluate(_ snapshot: Snapshot) -> [Advisory] {
        snapshot.devices(.microphone).compactMap { mic in
            guard mic.transport == .bluetooth, snapshot.isLive(mic),
                  let rate = snapshot.sampleRates[mic.id], rate <= callModeMaxRate else { return nil }
            let fix = snapshot.devices(.microphone).first { $0.transport == .builtIn }
                ?? snapshot.devices(.microphone).first { $0.transport == .usb }
            return Advisory(kind: .callQuality, device: mic, apps: snapshot.liveApps(mic), fix: fix)
        }
    }
}
