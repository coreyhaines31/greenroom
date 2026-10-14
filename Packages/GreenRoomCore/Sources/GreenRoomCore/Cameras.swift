import AVFoundation

/// Lists cameras: built-in, USB webcams, capture cards, and iPhones over Continuity Camera.
public enum Cameras {
    static let types: [AVCaptureDevice.DeviceType] = [.builtInWideAngleCamera, .external, .continuityCamera]

    public static func captureDevices() -> [AVCaptureDevice] {
        AVCaptureDevice.DiscoverySession(deviceTypes: types, mediaType: .video, position: .unspecified).devices
    }

    public static func devices() -> [Device] {
        captureDevices()
            .map(device(for:))
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    /// There's no system default camera. This is the one macOS suggests to apps that ask
    /// (FaceTime, Photo Booth, and apps that follow it); Zoom and Meet keep their own choice.
    public static func preferred() -> Device? {
        AVCaptureDevice.systemPreferredCamera.map(device(for:))
    }

    public static func setPreferred(_ device: Device) {
        AVCaptureDevice.userPreferredCamera = captureDevices().first { $0.uniqueID == device.id }
    }

    public static func captureDevice(for device: Device) -> AVCaptureDevice? {
        captureDevices().first { $0.uniqueID == device.id }
    }

    static func device(for capture: AVCaptureDevice) -> Device {
        Device(id: capture.uniqueID, name: capture.localizedName, kind: .camera, transport: transport(capture))
    }

    static func transport(_ capture: AVCaptureDevice) -> Transport {
        // Recent macOS reports iPhones as `.external`, so check the flag too.
        if capture.isContinuityCamera { return .continuity }
        return switch capture.deviceType {
        case .builtInWideAngleCamera: .builtIn
        case .continuityCamera: .continuity
        case .external: .external
        default: .other
        }
    }
}

public enum DeviceScanner {
    public static func snapshot() -> Snapshot {
        var snapshot = Snapshot()
        snapshot.devices[.camera] = Cameras.devices()
        snapshot.active[.camera] = Cameras.preferred()
        for kind in [DeviceKind.microphone, .speaker] {
            snapshot.devices[kind] = AudioHardware.devices(kind)
            snapshot.active[kind] = AudioHardware.defaultDevice(kind)
        }
        snapshot.live = LiveDevices.current()
        snapshot.sampleRates = AudioHardware.microphoneSampleRates()
        return snapshot
    }
}
