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
        /// Apps using the camera right now, which may have picked a smaller format.
        public var cameraApps: [String]
        public var micName: String?
        public var micSampleRate: Double?
        public var freeBytes: Int64?
        public var onBattery: Bool
        public var lowPowerMode: Bool

        public init(
            cameraName: String?, cameraWidth: Int, cameraHeight: Int, cameraFPS: Int, cameraMaxHeight: Int,
            cameraApps: [String] = [], micName: String?, micSampleRate: Double?, freeBytes: Int64?, onBattery: Bool,
            lowPowerMode: Bool
        ) {
            self.cameraMaxHeight = cameraMaxHeight
            self.cameraApps = cameraApps
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
                ? Item(title: mic, detail: "\(khz) kHz", passed: true)
                : Item(title: mic, detail: "\(khz) kHz is phone-call quality. Record with a USB or built-in mic.",
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

    /// Below 1080p is the most common recording mistake, and the fix depends on why.
    static func cameraItem(_ inputs: Inputs) -> Item {
        guard let camera = inputs.cameraName else {
            return Item(title: "No camera", detail: "Connect or pick a camera.", passed: false)
        }
        let size = "\(inputs.cameraWidth)×\(inputs.cameraHeight), up to \(inputs.cameraFPS) fps"
        if inputs.cameraHeight >= 1080 {
            return Item(title: camera, detail: size, passed: true)
        }
        if inputs.cameraMaxHeight >= 1080 {
            let who = inputs.cameraApps.isEmpty
                ? "The app using it" : ListFormatter.localizedString(byJoining: inputs.cameraApps)
            return Item(
                title: camera,
                detail: "\(size) right now, though it can do \(inputs.cameraMaxHeight)p. "
                    + "\(who) may have picked the lower size; check its video settings.",
                passed: false
            )
        }
        return Item(
            title: camera,
            detail: "\(size), its best right now. For a capture card, set the camera's HDMI output to 1080p or 4K.",
            passed: false
        )
    }

    /// Reads the current camera format, mic rate, free space, and power state.
    public static func currentInputs(camera: Device?, mic: Device?, sampleRates: [String: Double]) -> Inputs {
        let capture = camera.flatMap(Cameras.captureDevice(for:))
        let dimensions = capture.map { CMVideoFormatDescriptionGetDimensions($0.activeFormat.formatDescription) }
        let fps = capture?.activeFormat.videoSupportedFrameRateRanges.map(\.maxFrameRate).max() ?? 0
        let maxHeight = capture?.formats
            .map { CMVideoFormatDescriptionGetDimensions($0.formatDescription).height }
            .max()
        let home = URL(fileURLWithPath: NSHomeDirectory())
        let free = try? home.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
            .volumeAvailableCapacityForImportantUsage
        return Inputs(
            cameraName: camera?.name, cameraWidth: Int(dimensions?.width ?? 0),
            cameraHeight: Int(dimensions?.height ?? 0),
            cameraFPS: Int(fps.rounded()), cameraMaxHeight: Int(maxHeight ?? 0),
            cameraApps: [], micName: mic?.name, micSampleRate: mic.flatMap { sampleRates[$0.id] },
            freeBytes: free, onBattery: onBattery(), lowPowerMode: ProcessInfo.processInfo.isLowPowerModeEnabled
        )
    }

    static func onBattery() -> Bool {
        guard let info = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let source = IOPSGetProvidingPowerSourceType(info)?.takeUnretainedValue() else { return false }
        return (source as String) == kIOPMBatteryPowerKey
    }
}
