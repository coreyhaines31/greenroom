import CoreAudio
import os

/// Reads one microphone's level straight from Core Audio, without making it the default.
/// Each tap opens the device (and turns on the mic indicator), so only keep one while
/// someone is looking.
public final class InputTap: @unchecked Sendable {
    private let deviceID: AudioObjectID
    private let procID: AudioDeviceIOProcID
    private let peak: OSAllocatedUnfairLock<Float>

    public init?(_ device: Device) {
        guard device.kind == .microphone,
              let id = AudioHardware.deviceIDs().first(where: { AudioHardware.uid($0) == device.id }) else {
            return nil
        }
        let peak = OSAllocatedUnfairLock<Float>(initialState: 0)
        var procID: AudioDeviceIOProcID?
        let status = AudioDeviceCreateIOProcIDWithBlock(&procID, id, nil) { _, input, _, _, _ in
            let level = Self.level(input)
            peak.withLock { $0 = max($0, level) }
        }
        guard status == noErr, let procID else { return nil }
        guard AudioDeviceStart(id, procID) == noErr else {
            AudioDeviceDestroyIOProcID(id, procID)
            return nil
        }
        self.deviceID = id
        self.procID = procID
        self.peak = peak
    }

    /// The loudest moment since the last read: 0 is silence (-60 dB or quieter), 1 is full scale.
    public func read() -> Float {
        peak.withLock { peak in
            defer { peak = 0 }
            return peak
        }
    }

    public func stop() {
        AudioDeviceStop(deviceID, procID)
        AudioDeviceDestroyIOProcID(deviceID, procID)
    }

    /// Core Audio hands IO procs 32-bit float samples, one buffer per stream.
    static func level(_ list: UnsafePointer<AudioBufferList>) -> Float {
        var sum: Float = 0
        var total: Float = 0
        for buffer in UnsafeMutableAudioBufferListPointer(UnsafeMutablePointer(mutating: list)) {
            guard let data = buffer.mData else { continue }
            let samples = data.assumingMemoryBound(to: Float32.self)
            let length = Int(buffer.mDataByteSize) / MemoryLayout<Float32>.size
            for index in 0..<length { sum += samples[index] * samples[index] }
            total += Float(length)
        }
        guard total > 0 else { return 0 }
        let decibels = 20 * log10(max((sum / total).squareRoot(), 0.000_001))
        return min(1, max(0, (decibels + 60) / 60))
    }
}
