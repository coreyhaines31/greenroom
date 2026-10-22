@testable import GreenRoomCore
import Testing

struct MicSignalCheckTests {
    @Test func poweredOffCameraSendingZeroesWarnsAfterFourSeconds() {
        var check = MicSignalCheck(started: 100)
        #expect(check.observe(level: 0, now: 101) == .listening)
        #expect(check.observe(level: 0, now: 103.9) == .listening)
        #expect(check.observe(level: 0, now: 104) == .silent)
    }

    @Test func missingCallbacksNeverLookLikeAWorkingMic() {
        var check = MicSignalCheck(started: 0)
        #expect(check.observe(level: nil, now: 3) == .listening)
        #expect(check.observe(level: nil, now: 4) == .unavailable)
    }

    @Test func soundEndsTheCheckSoLaterPausesDontWarn() {
        var check = MicSignalCheck(started: 0)
        #expect(check.observe(level: 0.4, now: 1) == .soundDetected)
        #expect(check.observe(level: 0, now: 20) == .soundDetected)
    }

    @Test func noiseFloorDoesNotCountAsSound() {
        var check = MicSignalCheck(started: 0)
        #expect(check.observe(level: 0.09, now: 1) == .listening)
        #expect(check.observe(level: 0.1, now: 4) == .silent)
    }

    @Test func bluetoothGetsTimeToSettle() {
        var check = MicSignalCheck(started: 0, bluetooth: true)
        #expect(check.observe(level: 0, now: 4) == .listening)
        #expect(check.observe(level: 0.3, now: 9) == .soundDetected)
        var silent = MicSignalCheck(started: 0, bluetooth: true)
        #expect(silent.observe(level: 0, now: 10) == .silent)
    }

    @Test func invalidSamplesDoNotCountAsAudio() {
        var check = MicSignalCheck(started: 0)
        #expect(check.observe(level: .nan, now: 1) == .listening)
        #expect(check.observe(level: .infinity, now: 4) == .unavailable)
    }
}
