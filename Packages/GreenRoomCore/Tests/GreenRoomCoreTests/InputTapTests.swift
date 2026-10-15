import CoreAudio
@testable import GreenRoomCore
import Testing

struct InputTapTests {
    func level(of samples: [Float32]) -> Float {
        var samples = samples
        return samples.withUnsafeMutableBytes { bytes in
            var list = AudioBufferList(
                mNumberBuffers: 1,
                mBuffers: AudioBuffer(mNumberChannels: 1, mDataByteSize: UInt32(bytes.count), mData: bytes.baseAddress)
            )
            return InputTap.level(&list)
        }
    }

    @Test func silenceReadsZero() {
        #expect(level(of: Array(repeating: 0, count: 512)) == 0)
    }

    @Test func fullScaleReadsOne() {
        #expect(level(of: Array(repeating: 1, count: 512)) == 1)
    }

    @Test func quietSpeechReadsLow() {
        // -40 dB is a third of the way up the -60 dB to 0 dB meter.
        let quiet = Array(repeating: Float32(0.01), count: 512)
        #expect(abs(level(of: quiet) - 1.0 / 3) < 0.01)
    }

    @Test func emptyBufferReadsZero() {
        #expect(level(of: []) == 0)
    }
}
