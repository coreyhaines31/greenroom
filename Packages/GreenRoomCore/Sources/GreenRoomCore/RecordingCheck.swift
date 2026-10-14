import AVFoundation
import Foundation
import IOKit.ps

/// "Ready to record?": the things that ruin a take but don't matter on a call.
public struct RecordingCheck: Codable, Sendable, Equatable {
    public struct Item: Codable, Sendable, Equatable {
        public let title: String
        public let detail: String
        public let passed: Bool
    }

    public struct Inputs: Sendable, Equatable {
        public var cameraName: String?
        public var cameraWidth: Int
        public var cameraHeight: Int
        public var cameraFPS: Int
        /// The tallest format the camera offers. A capture card only offers what its input sends.
        public var cameraMaxHeight: Int
        /// Another app has the camera open, so its current format is what that app records.
        /// Otherwise the current format is just a default and says nothing.
        public var cameraInUseElsewhere: Bool
        public var micName: String?
        public var micSampleRate: Double?
        public var freeBytes: Int64?
        public var onBattery: Bool
        public var lowPowerMode: Bool

        public init(
            cameraName: String?, cameraWidth: Int, cameraHeight: Int, cameraFPS: Int, cameraMaxHeight: Int,
            cameraInUseElsewhere: Bool = false, micName: String?, micSampleRate: Double?, freeBytes: Int64?,
            onBattery: Bool, lowPowerMode: Bool
        ) {
            self.cameraMaxHeight = cameraMaxHeight
            self.cameraInUseElsewhere = cameraInUseElsewhere
            self.cameraName = cameraName
            self.cameraWidth = cameraWidth
            self.cameraHeight = cameraHeight
            self.cameraFPS = cameraFPS
            self.micName = micName
            self.micSampleRate = micSampleRate
            self.freeBytes = freeBytes
            self.onBattery = onBattery
            self.lowPowerMode = lowPowerMode
        }
    }

    public let items: [Item]
    public var ready: Bool { items.allSatisfy(\.passed) }

    /// Enough for about an hour of 4K from a typical camera.
    public static let minimumFreeBytes: Int64 = 20_000_000_000

    public static func evaluate(_ inputs: Inputs) -> RecordingCheck {
        var items: [Item] = []
        items.append(cameraItem(inputs))
        if let mic = inputs.micName, let rate = inputs.micSampleRate {
            let whole = rate.truncatingRemainder(dividingBy: 1000) == 0
            let khz = whole ? "\(Int(rate / 1000))" : String(format: "%.1f", rate / 1000)
            items.append(rate >= 44_100
                ? Item(title: "Microphone", detail: "\(mic) · \(khz) kHz", passed: true)
                : Item(title: "Microphone",
                       detail: "\(mic) · \(khz) kHz is phone-call quality. Record with a USB or built-in mic.",
                       passed: false))
        }
        if let free = inputs.freeBytes {
            let text = ByteCountFormatter.string(fromByteCount: free, countStyle: .file)
            items.append(free >= minimumFreeBytes
                ? Item(title: "Disk space", detail: "\(text) free", passed: true)
                : Item(title: "Disk space", detail: "Only \(text) free. A long 4K take can fill that.", passed: false))
        }
        if inputs.lowPowerMode {
            items.append(Item(
                title: "Low Power Mode is on", detail: "It can drop frames. Turn it off in System Settings › Battery.",
                passed: false
            ))
        } else if inputs.onBattery {
            items.append(Item(
                title: "On battery", detail: "Plug in so a long take doesn't drain or slow down your Mac.",
                passed: false
            ))
        } else {
            items.append(Item(title: "Power", detail: "Plugged in", passed: true))
        }
        return RecordingCheck(items: items)
    }

    /// Below 1080p is the most common recording mistake, and the fix depends on why: an app
    /// recording at a smaller size, or a camera (often a capture card) that can't do better.
    static func cameraItem(_ inputs: Inputs) -> Item {
        guard let camera = inputs.cameraName else {
            return Item(title: "Camera", detail: "None connected. Connect or pick a camera.", passed: false)
        }
        let current = "\(inputs.cameraWidth)×\(inputs.cameraHeight)"
        if inputs.cameraMaxHeight < 1080 {
            return Item(
                title: "Camera",
                detail: "\(camera) · \(inputs.cameraMaxHeight)p at most right now. "
                    + "For a capture card, set the camera's HDMI output to 1080p or 4K.",
                passed: false
            )
        }
        if inputs.cameraInUseElsewhere, inputs.cameraHeight < 1080 {
            return Item(
                title: "Camera",
                detail: "\(camera) · an app is using it at \(current), though it can do \(inputs.cameraMaxHeight)p. "
                    + "Check that app's video settings.",
                passed: false
            )
        }
        let now = inputs.cameraInUseElsewhere ? ", \(current) in use now" : ""
        return Item(title: "Camera", detail: "\(camera) · up to \(inputs.cameraMaxHeight)p\(now)", passed: true)
    }

    /// Reads the current camera format, mic rate, free space, and power state.
    public static func currentInputs(camera: Device?, mic: Device?, sampleRates: [String: Double]) -> Inputs {
        let capture = camera.flatMap(Cameras.captureDevice(for:))
        let dimensions = capture.map { CMVideoFormatDescriptionGetDimensions($0.activeFormat.formatDescription) }
        let maxHeight = capture?.formats
            .map { CMVideoFormatDescriptionGetDimensions($0.formatDescription).height }
            .max()
        let home = URL(fileURLWithPath: NSHomeDirectory())
        let free = try? home.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
            .volumeAvailableCapacityForImportantUsage
        return Inputs(
            cameraName: camera?.name, cameraWidth: Int(dimensions?.width ?? 0),
            cameraHeight: Int(dimensions?.height ?? 0),
            cameraFPS: 0, cameraMaxHeight: Int(maxHeight ?? 0),
            cameraInUseElsewhere: capture?.isInUseByAnotherApplication ?? false,
            micName: mic?.name, micSampleRate: mic.flatMap { sampleRates[$0.id] },
            freeBytes: free, onBattery: onBattery(), lowPowerMode: ProcessInfo.processInfo.isLowPowerModeEnabled
        )
    }

    static func onBattery() -> Bool {
        guard let info = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let source = IOPSGetProvidingPowerSourceType(info)?.takeUnretainedValue() else { return false }
        return (source as String) == kIOPMBatteryPowerKey
    }
}
