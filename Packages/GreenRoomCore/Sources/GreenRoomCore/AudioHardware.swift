import CoreAudio
import Foundation

/// Reads and sets the system's microphones and speakers through Core Audio.
public enum AudioHardware {
    static let system = AudioObjectID(kAudioObjectSystemObject)

    public static func devices(_ kind: DeviceKind) -> [Device] {
        precondition(kind != .camera)
        let scope = kind == .microphone ? kAudioObjectPropertyScopeInput : kAudioObjectPropertyScopeOutput
        return deviceIDs()
            .filter { hasStreams($0, scope: scope) && !isHidden($0) }
            .compactMap { device(for: $0, kind: kind) }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    public static func defaultDevice(_ kind: DeviceKind) -> Device? {
        precondition(kind != .camera)
        var id = AudioObjectID(kAudioObjectUnknown)
        var size = UInt32(MemoryLayout<AudioObjectID>.size)
        var addr = address(defaultSelector(kind))
        guard AudioObjectGetPropertyData(system, &addr, 0, nil, &size, &id) == noErr,
              id != kAudioObjectUnknown else { return nil }
        return device(for: id, kind: kind)
    }

    /// Makes the device the system default, the same as picking it in System Settings › Sound.
    @discardableResult
    public static func setDefault(_ device: Device) -> Bool {
        guard device.kind != .camera,
              let id = deviceIDs().first(where: { uid($0) == device.id }) else { return false }
        var value = id
        var addr = address(defaultSelector(device.kind))
        return AudioObjectSetPropertyData(
            system, &addr, 0, nil, UInt32(MemoryLayout<AudioObjectID>.size), &value
        ) == noErr
    }

    /// Checks macOS's own mute switch and input volume. Many USB mics expose neither, which
    /// reads as fine here; the level meter catches the rest.
    public static func micProblem(_ device: Device) -> MicProblem? {
        guard device.kind == .microphone,
              let id = deviceIDs().first(where: { uid($0) == device.id }) else { return nil }
        for element in [kAudioObjectPropertyElementMain, 1] {
            if let mute = scalar(id, kAudioDevicePropertyMute, element: element, as: UInt32.self), mute != 0 {
                return .muted
            }
        }
        for element in [kAudioObjectPropertyElementMain, 1] {
            if let volume = scalar(id, kAudioDevicePropertyVolumeScalar, element: element, as: Float32.self) {
                return volume <= 0.001 ? .volumeZero : nil
            }
        }
        return nil
    }

    static func scalar<T: Numeric>(
        _ id: AudioObjectID, _ selector: AudioObjectPropertySelector, element: UInt32, as type: T.Type
    ) -> T? {
        var addr = AudioObjectPropertyAddress(
            mSelector: selector, mScope: kAudioObjectPropertyScopeInput, mElement: element
        )
        guard AudioObjectHasProperty(id, &addr) else { return nil }
        var value: T = 0
        var size = UInt32(MemoryLayout<T>.size)
        guard AudioObjectGetPropertyData(id, &addr, 0, nil, &size, &value) == noErr else { return nil }
        return value
    }

    static func device(for id: AudioObjectID, kind: DeviceKind) -> Device? {
        // Core Audio makes these on the fly when an app (this one included) opens the
        // default device. They aren't hardware, and they come and go.
        guard let uid = uid(id), !uid.hasPrefix("CADefaultDeviceAggregate") else { return nil }
        let name = string(id, kAudioObjectPropertyName) ?? "Unknown device"
        return Device(id: uid, name: name, kind: kind, transport: transport(transportType(id)))
    }

    static func transport(_ type: UInt32) -> Transport {
        switch type {
        case kAudioDeviceTransportTypeBuiltIn: .builtIn
        case kAudioDeviceTransportTypeUSB: .usb
        case kAudioDeviceTransportTypeBluetooth, kAudioDeviceTransportTypeBluetoothLE: .bluetooth
        case kAudioDeviceTransportTypeAirPlay: .airPlay
        case kAudioDeviceTransportTypeThunderbolt: .thunderbolt
        case kAudioDeviceTransportTypeHDMI, kAudioDeviceTransportTypeDisplayPort: .display
        case kAudioDeviceTransportTypeContinuityCaptureWired, kAudioDeviceTransportTypeContinuityCaptureWireless:
            .continuity
        case kAudioDeviceTransportTypeVirtual: .virtual
        case kAudioDeviceTransportTypeAggregate, kAudioDeviceTransportTypeAutoAggregate: .aggregate
        default: .other
        }
    }

    static func defaultSelector(_ kind: DeviceKind) -> AudioObjectPropertySelector {
        kind == .microphone ? kAudioHardwarePropertyDefaultInputDevice : kAudioHardwarePropertyDefaultOutputDevice
    }

    static func address(
        _ selector: AudioObjectPropertySelector, scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal
    ) -> AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(mSelector: selector, mScope: scope, mElement: kAudioObjectPropertyElementMain)
    }

    static func deviceIDs() -> [AudioObjectID] {
        var addr = address(kAudioHardwarePropertyDevices)
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(system, &addr, 0, nil, &size) == noErr else { return [] }
        var ids = [AudioObjectID](repeating: 0, count: Int(size) / MemoryLayout<AudioObjectID>.size)
        guard AudioObjectGetPropertyData(system, &addr, 0, nil, &size, &ids) == noErr else { return [] }
        return ids
    }

    static func uid(_ id: AudioObjectID) -> String? { string(id, kAudioDevicePropertyDeviceUID) }

    static func string(_ id: AudioObjectID, _ selector: AudioObjectPropertySelector) -> String? {
        var addr = address(selector)
        var value: Unmanaged<CFString>?
        var size = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
        let status = withUnsafeMutablePointer(to: &value) {
            AudioObjectGetPropertyData(id, &addr, 0, nil, &size, $0)
        }
        guard status == noErr, let value else { return nil }
        return value.takeRetainedValue() as String
    }

    static func uint32(_ id: AudioObjectID, _ selector: AudioObjectPropertySelector) -> UInt32 {
        var addr = address(selector)
        var value: UInt32 = 0
        var size = UInt32(MemoryLayout<UInt32>.size)
        guard AudioObjectGetPropertyData(id, &addr, 0, nil, &size, &value) == noErr else { return 0 }
        return value
    }

    static func transportType(_ id: AudioObjectID) -> UInt32 { uint32(id, kAudioDevicePropertyTransportType) }
    static func isHidden(_ id: AudioObjectID) -> Bool { uint32(id, kAudioDevicePropertyIsHidden) != 0 }

    static func hasStreams(_ id: AudioObjectID, scope: AudioObjectPropertyScope) -> Bool {
        var addr = address(kAudioDevicePropertyStreams, scope: scope)
        var size: UInt32 = 0
        return AudioObjectGetPropertyDataSize(id, &addr, 0, nil, &size) == noErr && size > 0
    }
}

/// Calls back on the main queue when a device is plugged in or removed, or a default changes.
public final class AudioChangeListener {
    private let handler: @MainActor @Sendable () -> Void
    private var registered: [(AudioObjectPropertyAddress, AudioObjectPropertyListenerBlock)] = []

    public init(handler: @escaping @MainActor @Sendable () -> Void) {
        self.handler = handler
    }

    public func start() {
        let selectors = [
            kAudioHardwarePropertyDevices,
            kAudioHardwarePropertyDefaultInputDevice,
            kAudioHardwarePropertyDefaultOutputDevice
        ]
        for selector in selectors {
            var addr = AudioHardware.address(selector)
            let handler = self.handler
            let block: AudioObjectPropertyListenerBlock = { _, _ in
                MainActor.assumeIsolated { handler() }
            }
            if AudioObjectAddPropertyListenerBlock(AudioHardware.system, &addr, .main, block) == noErr {
                registered.append((addr, block))
            }
        }
    }

    public func stop() {
        for (addr, block) in registered {
            var addr = addr
            AudioObjectRemovePropertyListenerBlock(AudioHardware.system, &addr, .main, block)
        }
        registered = []
    }

    deinit { stop() }
}
