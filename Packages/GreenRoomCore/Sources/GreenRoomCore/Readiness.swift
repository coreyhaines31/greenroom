import Foundation

/// The devices you expect for a call or a recording, e.g. "Studio: ZV-E10 + Shure MV7 + monitors".
public struct Setup: Codable, Sendable, Equatable {
    public var name: String
    public var devices: [DeviceKind: Device]

    public init(name: String, devices: [DeviceKind: Device]) {
        self.name = name
        self.devices = devices
    }

    /// Saves whatever is active right now.
    public static func current(_ snapshot: Snapshot, name: String = "My setup") -> Setup {
        Setup(name: name, devices: snapshot.active)
    }
}

public struct Mismatch: Sendable, Equatable {
    public enum Problem: Sendable, Equatable {
        case missing
        case notSelected(actual: Device?)
    }

    public let kind: DeviceKind
    public let expected: Device
    public let problem: Problem

    public var message: String {
        switch problem {
        case .missing:
            return "\(expected.name) isn't connected"
        case .notSelected(let actual?):
            let lead = kind == .speaker ? "Sound is going to" : "\(kind.title) is"
            return "\(lead) \(actual.name), not \(expected.name)"
        case .notSelected(nil):
            return "No \(kind.title.lowercased()) selected"
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
            } else if kind != .camera, snapshot.active(kind)?.id != expected.id {
                // Cameras only need to be connected: each call app picks its own.
                let problem = Mismatch.Problem.notSelected(actual: snapshot.active(kind))
                issues.append(Mismatch(kind: kind, expected: expected, problem: problem))
            }
        }
        return issues.isEmpty ? .ready : .notReady(issues)
    }
}
