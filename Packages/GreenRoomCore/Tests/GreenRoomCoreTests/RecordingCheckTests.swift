@testable import GreenRoomCore
import Testing

struct RecordingCheckTests {
    func inputs(height: Int = 1080, rate: Double = 48_000, free: Int64 = 100_000_000_000, battery: Bool = false)
        -> RecordingCheck.Inputs {
        RecordingCheck.Inputs(
            cameraName: "Cam Link 4K", cameraWidth: height * 16 / 9, cameraHeight: height, cameraFPS: 60,
            cameraMaxHeight: 2160, cameraApps: ["Loom"],
            micName: "Shure MV7", micSampleRate: rate, freeBytes: free, onBattery: battery, lowPowerMode: false
        )
    }

    @Test func readyWhenEverythingIsGood() {
        let check = RecordingCheck.evaluate(inputs())
        #expect(check.ready)
        #expect(check.items.first?.detail == "Cam Link 4K · 1920×1080, up to 60 fps")
    }

    @Test func flagsWhatWouldRuinATake() {
        let check = RecordingCheck.evaluate(inputs(height: 720, rate: 16_000, free: 5_000_000_000, battery: true))
        #expect(!check.ready)
        #expect(check.items.filter { !$0.passed }.count == 4)
        #expect(check.items[1].detail.hasPrefix("Shure MV7 · 16 kHz is phone-call quality"))
        #expect(check.items[0].detail.contains("Loom may have picked the lower size"))
    }
}
