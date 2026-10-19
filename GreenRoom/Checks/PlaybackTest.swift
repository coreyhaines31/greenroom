import AVFoundation
import Observation

/// "Hear yourself": records five seconds from the default mic, then plays it back through the
/// default speaker. A meter proves the mic hears something; this proves you sound right. The
/// recording only ever lives in memory and is dropped when playback ends.
@MainActor
@Observable
final class PlaybackTest {
    enum Phase: Equatable {
        case idle
        case recording(secondsLeft: Int)
        case playing
    }

    private(set) var phase = Phase.idle

    var buttonTitle: String {
        switch phase {
        case .idle: "Hear Yourself"
        case .recording(let left): "Talk… \(left)"
        case .playing: "Playing…"
        }
    }
    @ObservationIgnored private var engine: AVAudioEngine?
    @ObservationIgnored private var task: Task<Void, Never>?

    nonisolated static let seconds = 5

    /// Buffers arrive on the audio thread, so they're collected behind a lock.
    final class Recording: @unchecked Sendable {
        private let lock = NSLock()
        private var buffers: [AVAudioPCMBuffer] = []

        /// Copies the raw bytes of each audio buffer, so any sample format and layout works.
        func append(_ buffer: AVAudioPCMBuffer) {
            guard let copy = AVAudioPCMBuffer(pcmFormat: buffer.format, frameCapacity: buffer.frameLength) else {
                return
            }
            copy.frameLength = buffer.frameLength
            let source = UnsafeMutableAudioBufferListPointer(UnsafeMutablePointer(mutating: buffer.audioBufferList))
            let target = UnsafeMutableAudioBufferListPointer(copy.mutableAudioBufferList)
            for (from, to) in zip(source, target) {
                guard let bytes = from.mData, let destination = to.mData else { continue }
                memcpy(destination, bytes, Int(min(from.mDataByteSize, to.mDataByteSize)))
            }
            lock.withLock { buffers.append(copy) }
        }

        var all: [AVAudioPCMBuffer] { lock.withLock { buffers } }
    }

    func start(onDone: @escaping @MainActor () -> Void) {
        guard phase == .idle else { return }
        let recording = Recording()
        let engine = AVAudioEngine()
        let format = engine.inputNode.outputFormat(forBus: 0)
        guard format.sampleRate > 0, format.channelCount > 0 else { return onDone() }
        engine.inputNode.installTap(onBus: 0, bufferSize: 4096, format: format, block: Self.tap(into: recording))
        do { try engine.start() } catch { return onDone() }
        self.engine = engine
        // A different default mic mid-recording reconfigures the engine; stop rather than play junk.
        let changed = NotificationCenter.default.addObserver(
            forName: .AVAudioEngineConfigurationChange, object: engine, queue: .main
        ) { _ in MainActor.assumeIsolated { [weak self] in self?.cancel(); onDone() } }
        task = Task {
            defer { NotificationCenter.default.removeObserver(changed) }
            for left in stride(from: Self.seconds, to: 0, by: -1) {
                phase = .recording(secondsLeft: left)
                try? await Task.sleep(for: .seconds(1))
                if Task.isCancelled { return }
            }
            NotificationCenter.default.removeObserver(changed)
            engine.inputNode.removeTap(onBus: 0)
            engine.stop()
            await play(recording.all, format: format)
            phase = .idle
            self.engine = nil
            onDone()
        }
    }

    func cancel() {
        task?.cancel()
        engine?.inputNode.removeTap(onBus: 0)
        engine?.stop()
        engine = nil
        phase = .idle
    }

    private func play(_ buffers: [AVAudioPCMBuffer], format: AVAudioFormat) async {
        guard !buffers.isEmpty else { return }
        phase = .playing
        let engine = AVAudioEngine()
        let player = AVAudioPlayerNode()
        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: format)
        do { try engine.start() } catch { return }
        self.engine = engine
        for buffer in buffers {
            player.scheduleBuffer(buffer, completionHandler: nil)
        }
        player.play()
        let frames = buffers.reduce(0) { $0 + Double($1.frameLength) }
        try? await Task.sleep(for: .seconds(frames / format.sampleRate + 0.3))
        player.stop()
        engine.stop()
    }

    /// Built outside the main actor: the tap runs on a real-time audio thread.
    nonisolated static func tap(into recording: Recording) -> AVAudioNodeTapBlock {
        { buffer, _ in recording.append(buffer) }
    }
}
