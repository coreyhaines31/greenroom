import AVFoundation
import Observation

/// A level meter on the system's default microphone, the same input call apps get by default.
@MainActor
@Observable
final class MicMeter {
    /// 0 is silence (-60 dB or quieter), 1 is full scale.
    private(set) var level: Float = 0 {
        didSet {
            // The clock starts with the first audio, not when the meter opens: Bluetooth
            // headsets take a few seconds to switch into mic mode and send nothing meanwhile.
            if level > Self.soundLevel || lastSound == nil { lastSound = .now }
            isSilent = lastSound.map { Date.now.timeIntervalSince($0) > silentSeconds } ?? false
        }
    }
    /// True after a few seconds with nothing above room noise.
    private(set) var isSilent = false
    @ObservationIgnored private var engine: AVAudioEngine?
    @ObservationIgnored private var lastSound: Date?
    @ObservationIgnored private var silentSeconds: TimeInterval = 5

    static let soundLevel: Float = 0.1

    /// Bluetooth mics get longer: their first seconds of audio are often silence.
    func start(bluetooth: Bool = false) {
        silentSeconds = bluetooth ? 10 : 5
        let engine = AVAudioEngine()
        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        guard format.sampleRate > 0, format.channelCount > 0 else { return }
        lastSound = nil
        isSilent = false
        input.installTap(onBus: 0, bufferSize: 1024, format: format, block: Self.tap { [weak self] level in
            DispatchQueue.main.async { MainActor.assumeIsolated { self?.level = level } }
        })
        do {
            try engine.start()
            self.engine = engine
        } catch {
            input.removeTap(onBus: 0)
        }
    }

    func stop() {
        engine?.inputNode.removeTap(onBus: 0)
        engine?.stop()
        engine = nil
        level = 0
        isSilent = false
    }

    /// Built outside the main actor: the tap runs on a real-time audio thread.
    nonisolated static func tap(_ onLevel: @escaping @Sendable (Float) -> Void) -> AVAudioNodeTapBlock {
        { buffer, _ in
            guard let samples = buffer.floatChannelData?[0], buffer.frameLength > 0 else { return }
            let count = Int(buffer.frameLength)
            var sum: Float = 0
            for index in 0..<count { sum += samples[index] * samples[index] }
            let rms = (sum / Float(count)).squareRoot()
            let decibels = 20 * log10(max(rms, 0.000_001))
            onLevel(min(1, max(0, (decibels + 60) / 60)))
        }
    }
}
