import Foundation

public enum DeviceKind: String, Codable, CodingKeyRepresentable, Sendable, CaseIterable {
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
/// An app with a device open right now. `app` is nil when macOS doesn't say which app
/// (cameras only report that some app has them).
public struct LiveUse: Codable, Sendable, Hashable {
    public let kind: DeviceKind
    public let deviceID: String
    public let app: String?

    public init(kind: DeviceKind, deviceID: String, app: String?) {
        self.kind = kind
        self.deviceID = deviceID
        self.app = app
    }
}

/// Everything connected right now, plus which device of each kind macOS will hand to apps,
/// and which ones other apps have open.
public struct Snapshot: Sendable, Equatable {
    public var devices: [DeviceKind: [Device]]
    public var active: [DeviceKind: Device]
    /// Devices other apps are using right now. Green Room's own use is left out.
    public var live: [LiveUse]
    /// Current sample rate of each microphone, by device ID. Bluetooth mics drop to 24 kHz
    /// or lower in call mode.
    public var sampleRates: [String: Double]

    public init(
        devices: [DeviceKind: [Device]] = [:], active: [DeviceKind: Device] = [:],
        live: [LiveUse] = [], sampleRates: [String: Double] = [:]
    ) {
        self.devices = devices
        self.active = active
        self.live = live
        self.sampleRates = sampleRates
    }

    public func devices(_ kind: DeviceKind) -> [Device] { devices[kind] ?? [] }
    public func active(_ kind: DeviceKind) -> Device? { active[kind] }

    public func contains(_ id: String, kind: DeviceKind) -> Bool {
        devices(kind).contains { $0.id == id }
    }

    public func device(_ id: String, kind: DeviceKind) -> Device? {
        devices(kind).first { $0.id == id }
    }

    /// Apps using this device right now, by name. Empty when it's idle.
    public func liveApps(_ device: Device) -> [String] {
        live.filter { $0.kind == device.kind && $0.deviceID == device.id }.map { $0.app ?? "Another app" }
    }

    public func isLive(_ device: Device) -> Bool {
        live.contains { $0.kind == device.kind && $0.deviceID == device.id }
    }

    /// Leaves out apps you've told Green Room to ignore, like a recorder that always listens.
    public func ignoring(apps: Set<String>) -> Snapshot {
        guard !apps.isEmpty else { return self }
        var copy = self
        copy.live = live.filter { use in use.app.map { !apps.contains($0) } ?? true }
        return copy
    }
}
