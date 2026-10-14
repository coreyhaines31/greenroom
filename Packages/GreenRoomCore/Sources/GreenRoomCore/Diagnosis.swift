import Foundation

/// Why a device you expect isn't showing up.
public enum MissingReason: Sendable, Equatable {
    /// Nothing by that name on USB: unplugged, or a bad cable, hub, or port.
    case notOnUSB
    /// On USB, but macOS isn't offering it as a camera or audio device.
    case onUSBButNotWorking
    case bluetoothNotConnected
    case notConnected

    public static func diagnose(name: String, transport: Transport, usbProducts: [String]) -> MissingReason {
        switch transport {
        case .usb, .external:
            USBDevices.matches(name, in: usbProducts) ? .onUSBButNotWorking : .notOnUSB
        case .bluetooth:
            .bluetoothNotConnected
        default:
            .notConnected
        }
    }

    public var headline: String {
        switch self {
        case .notOnUSB: "Not plugged in"
        case .onUSBButNotWorking: "Plugged in, but not working"
        case .bluetoothNotConnected: "Not connected"
        case .notConnected: "Not connected"
        }
    }

    public var advice: String {
        switch self {
        case .notOnUSB:
            "Your Mac doesn't see it on USB at all. Check the cable and hub, or try another port."
        case .onUSBButNotWorking:
            "Your Mac sees it on USB, but not as a camera or audio device. Unplug it and plug it back in."
        case .bluetoothNotConnected:
            "Turn it on, or connect it in Bluetooth settings."
        case .notConnected:
            "Reconnect it, then check again."
        }
    }
}

/// Why the selected microphone might be silent even though it's connected.
public enum MicProblem: Sendable, Equatable {
    case muted
    case volumeZero
    case silent

    public var message: String {
        switch self {
        case .muted: "This microphone is muted in macOS."
        case .volumeZero: "Input volume is at zero. Raise it in System Settings › Sound."
        case .silent: "No sound coming in. Check the mic's own mute button or gain knob."
        }
    }
}
