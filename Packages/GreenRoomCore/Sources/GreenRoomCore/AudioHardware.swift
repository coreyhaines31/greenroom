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
        let status = withUnsafeMutablePointer(to: &value) { AudioObjectGetPropertyData(id, &addr, 0, nil, &size, $0) }
        return status == noErr ? value : nil
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

    static func deviceIDs() -> [AudioObjectID] { objectList(system, kAudioHardwarePropertyDevices) }

    static func objectList(
        _ object: AudioObjectID, _ selector: AudioObjectPropertySelector,
        scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal
    ) -> [AudioObjectID] {
        var addr = address(selector, scope: scope)
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(object, &addr, 0, nil, &size) == noErr, size > 0 else { return [] }
        var ids = [AudioObjectID](repeating: 0, count: Int(size) / MemoryLayout<AudioObjectID>.size)
        guard AudioObjectGetPropertyData(object, &addr, 0, nil, &size, &ids) == noErr else { return [] }
        return ids
    }

    /// Nominal sample rate of each microphone, keyed by device UID.
    public static func microphoneSampleRates() -> [String: Double] {
        var rates: [String: Double] = [:]
        for id in deviceIDs() where hasStreams(id, scope: kAudioObjectPropertyScopeInput) {
            var addr = address(kAudioDevicePropertyNominalSampleRate)
            var rate: Float64 = 0
            var size = UInt32(MemoryLayout<Float64>.size)
            if let uid = uid(id), AudioObjectGetPropertyData(id, &addr, 0, nil, &size, &rate) == noErr {
                rates[uid] = rate
            }
        }
        return rates
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

/// Calls back on the main queue when a device is plugged in or removed, a default changes, or an
/// app starts or stops using a device. Call `stop()` when done.
@MainActor
public final class AudioChangeListener {
    private let handler: @MainActor @Sendable () -> Void
    private var system: [(AudioObjectPropertyAddress, AudioObjectPropertyListenerBlock)] = []
    private struct Registration {
        let object: AudioObjectID
        let address: AudioObjectPropertyAddress
        let block: AudioObjectPropertyListenerBlock
    }

    /// Listeners on each device and app, rebuilt whenever either list changes.
    private var perObject: [Registration] = []

    public init(handler: @escaping @MainActor @Sendable () -> Void) {
        self.handler = handler
    }

    public func start() {
        // Device and app lists need the per-object listeners rebuilt; default changes don't.
        var selectors = [
            (kAudioHardwarePropertyDevices, true),
            (kAudioHardwarePropertyDefaultInputDevice, false),
            (kAudioHardwarePropertyDefaultOutputDevice, false)
        ]
        if #available(macOS 14.2, *) { selectors.append((kAudioHardwarePropertyProcessObjectList, true)) }
        for (selector, rebuilds) in selectors {
            var addr = AudioHardware.address(selector)
            let block = makeBlock(rebuilding: rebuilds)
            if AudioObjectAddPropertyListenerBlock(AudioHardware.system, &addr, .main, block) == noErr {
                system.append((addr, block))
            }
        }
        rebuild()
    }

    public func stop() {
        for (addr, block) in system {
            var addr = addr
            AudioObjectRemovePropertyListenerBlock(AudioHardware.system, &addr, .main, block)
        }
        system = []
        removePerObject()
    }

    private func makeBlock(rebuilding: Bool) -> AudioObjectPropertyListenerBlock {
        let handler = self.handler
        return { [weak self] _, _ in
            MainActor.assumeIsolated {
                if rebuilding { self?.scheduleRebuild() }
                handler()
            }
        }
    }

    private var rebuildPending = false

    /// Apps come and go in bursts, so rebuilds are folded together.
    private func scheduleRebuild() {
        guard !rebuildPending else { return }
        rebuildPending = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
            MainActor.assumeIsolated {
                self?.rebuildPending = false
                self?.rebuild()
            }
        }
    }

    private func rebuild() {
        removePerObject()
        var targets: [(AudioObjectID, AudioObjectPropertySelector)] = []
        for device in AudioHardware.deviceIDs() {
            targets.append((device, kAudioDevicePropertyDeviceIsRunningSomewhere))
            targets.append((device, kAudioDevicePropertyNominalSampleRate))
        }
        if #available(macOS 14.2, *) {
            for process in AudioHardware.objectList(AudioHardware.system, kAudioHardwarePropertyProcessObjectList) {
                targets.append((process, kAudioProcessPropertyIsRunningInput))
                targets.append((process, kAudioProcessPropertyIsRunningOutput))
            }
        }
        for (object, selector) in targets {
            var addr = AudioHardware.address(selector)
            let block = makeBlock(rebuilding: false)
            if AudioObjectAddPropertyListenerBlock(object, &addr, .main, block) == noErr {
                perObject.append(Registration(object: object, address: addr, block: block))
            }
        }
    }

    private func removePerObject() {
        for registration in perObject {
            var addr = registration.address
            AudioObjectRemovePropertyListenerBlock(registration.object, &addr, .main, registration.block)
        }
        perObject = []
    }
}
