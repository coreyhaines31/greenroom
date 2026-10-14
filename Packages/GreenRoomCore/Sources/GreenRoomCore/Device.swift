import Foundation

public enum DeviceKind: String, Codable, Sendable, CaseIterable {
    case camera, microphone, speaker

    public var title: String {
        switch self {
        case .camera: "Camera"
        case .microphone: "Microphone"
        case .speaker: "Speaker"
        }
    }
}

/// How a device is attached. Shown next to its name, because "MacBook Pro Microphone" vs
/// "AirPods (Bluetooth)" is usually the whole question.
public enum Transport: String, Codable, Sendable {
    case builtIn, usb, bluetooth, airPlay, thunderbolt, display, continuity, external, virtual, aggregate, other

    public var label: String {
        switch self {
        case .builtIn: "Built-in"
        case .usb: "USB"
        case .bluetooth: "Bluetooth"
        case .airPlay: "AirPlay"
        case .thunderbolt: "Thunderbolt"
        case .display: "Display"
        case .continuity: "iPhone"
        case .external: "External"
        case .virtual: "Virtual"
        case .aggregate: "Aggregate"
        case .other: "Other"
        }
    }
}

public struct Device: Codable, Sendable, Hashable, Identifiable {
    /// Stable across reconnects and restarts (Core Audio UID or AVCaptureDevice uniqueID).
    public let id: String
    public let name: String
    public let kind: DeviceKind
    public let transport: Transport

    public init(id: String, name: String, kind: DeviceKind, transport: Transport) {
        self.id = id
        self.name = name
        self.kind = kind
        self.transport = transport
    }
}

/// Everything connected right now, plus which device of each kind macOS will hand to apps.
public struct Snapshot: Sendable, Equatable {
    public var devices: [DeviceKind: [Device]]
    public var active: [DeviceKind: Device]

    public init(devices: [DeviceKind: [Device]] = [:], active: [DeviceKind: Device] = [:]) {
        self.devices = devices
        self.active = active
    }

    public func devices(_ kind: DeviceKind) -> [Device] { devices[kind] ?? [] }
    public func active(_ kind: DeviceKind) -> Device? { active[kind] }

    public func contains(_ id: String, kind: DeviceKind) -> Bool {
        devices(kind).contains { $0.id == id }
    }
}
