@testable import GreenRoomCore
import Testing

struct RecordingCheckTests {
    func inputs(
        height: Int = 1080, max: Int = 2160, inUse: Bool = false, rate: Double = 48_000,
        free: Int64 = 100_000_000_000, battery: Bool = false
    ) -> RecordingCheck.Inputs {
        RecordingCheck.Inputs(
            cameraName: "Cam Link 4K", cameraWidth: height * 16 / 9, cameraHeight: height, cameraFPS: 60,
            cameraMaxHeight: max, cameraInUseElsewhere: inUse, micName: "Shure MV7", micSampleRate: rate,
            freeBytes: free, onBattery: battery, lowPowerMode: false
        )
    }

    @Test func readyWhenEverythingIsGood() {
        let check = RecordingCheck.evaluate(inputs())
        #expect(check.ready)
        #expect(check.items.first?.detail == "Cam Link 4K · up to 2160p")
    }

    @Test func aCameraNobodyIsUsingIsJudgedByItsBestFormat() {
        // Idle cameras report a default format; that's not a problem.
        #expect(RecordingCheck.evaluate(inputs(height: 720)).items.first?.passed == true)
    }

    @Test func flagsAnAppRecordingSmallAndACameraThatCantDoBetter() {
        let app = RecordingCheck.evaluate(inputs(height: 720, inUse: true)).items[0]
        #expect(!app.passed && app.detail.contains("an app is using it at 1280×720"))
        let card = RecordingCheck.evaluate(inputs(height: 720, max: 720)).items[0]
        #expect(!card.passed && card.detail.contains("HDMI output"))
    }

    @Test func flagsWhatWouldRuinATake() {
        let check = RecordingCheck.evaluate(inputs(rate: 16_000, free: 5_000_000_000, battery: true))
        #expect(check.items.filter { !$0.passed }.count == 3)
        #expect(check.items[1].detail.hasPrefix("Shure MV7 · 16 kHz is phone-call quality"))
    }
}
