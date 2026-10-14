import AVFoundation
import Observation

/// Plays a short tone in the left channel, then the right, through the default output.
@MainActor
@Observable
final class TestTone {
    enum Side { case left, right }

    private(set) var playing: Side?
    @ObservationIgnored private var engine: AVAudioEngine?

    nonisolated static let toneSeconds = 0.6

    func play() {
        stop()
        let engine = AVAudioEngine()
        let sampleRate = engine.outputNode.outputFormat(forBus: 0).sampleRate
        guard sampleRate > 0, let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 2) else {
            return
        }
        let source = AVAudioSourceNode(format: format, renderBlock: Self.render(sampleRate: sampleRate))
        engine.attach(source)
        engine.connect(source, to: engine.mainMixerNode, format: format)
        do {
            try engine.start()
        } catch {
            return
        }
        self.engine = engine
        playing = .left
        Task {
            try? await Task.sleep(for: .seconds(Self.toneSeconds))
            guard self.engine === engine else { return }
            playing = .right
            try? await Task.sleep(for: .seconds(Self.toneSeconds + 0.1))
            guard self.engine === engine else { return }
            stop()
        }
    }

    func stop() {
        engine?.stop()
        engine = nil
        playing = nil
    }

    final class Oscillator: @unchecked Sendable {
        var phase = 0.0
        var frame = 0
    }

    /// Built outside the main actor: rendering runs on a real-time audio thread.
    nonisolated static func render(sampleRate: Double) -> AVAudioSourceNodeRenderBlock {
        let oscillator = Oscillator()
        let half = Int(sampleRate * toneSeconds)
        let fade = sampleRate * 0.02
        let step = 2 * Double.pi * 440 / sampleRate
        return { _, _, frameCount, audioBufferList in
            let buffers = UnsafeMutableAudioBufferListPointer(audioBufferList)
            for index in 0..<Int(frameCount) {
                let frame = oscillator.frame
                var sample: Float = 0
                if frame < half * 2 {
                    let within = Double(frame % half)
                    let envelope = min(1, within / fade, (Double(half) - within) / fade)
                    sample = Float(sin(oscillator.phase) * 0.2 * envelope)
                    oscillator.phase += step
                }
                let leftHalf = frame < half
                for (channel, buffer) in buffers.enumerated() {
                    let output = buffer.mData?.assumingMemoryBound(to: Float.self)
                    output?[index] = (channel == 0) == leftHalf ? sample : 0
                }
                oscillator.frame += 1
            }
            return noErr
        }
    }
}
