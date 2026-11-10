@testable import GreenRoomCore
import Testing

struct ReadyCheckTests {
    let shure = Device(id: "mv7", name: "Shure MV7", kind: .microphone, transport: .usb)
    let speakers = Device(id: "spk", name: "MacBook Pro Speakers", kind: .speaker, transport: .builtIn)

    var matching: Snapshot {
        Snapshot(
            devices: [.microphone: [shure], .speaker: [speakers]], active: [.microphone: shure, .speaker: speakers]
        )
    }

    @Test func aMutedMicIsNotReadyEvenWhenTheSetupMatches() {
        let setup = Setup.current(matching, name: "Desk")
        #expect(ReadyCheck.evaluate(matching, setup: setup, micProblem: nil).isReady)
        for problem in [MicProblem.muted, .volumeZero] {
            let check = ReadyCheck.evaluate(matching, setup: setup, micProblem: problem)
            #expect(check.readiness == .ready)
            #expect(!check.isReady)
            let report = StatusReport.make(
                snapshot: matching, setup: setup, history: DeviceHistory(), usbProducts: [], micProblem: problem,
                now: .now
            )
            #expect(report.ready == check.isReady)
        }
    }

    @Test func aMutedMicIsNotReadyWithoutASetup() {
        #expect(!ReadyCheck.evaluate(matching, setup: nil, micProblem: .muted).isReady)
    }

    /// Silence needs the level meter, so it only shows in the open panel.
    @Test func silenceDoesNotCount() {
        let check = ReadyCheck.evaluate(matching, setup: .current(matching, name: "Desk"), micProblem: .silent)
        #expect(check.micProblem == nil)
        #expect(check.isReady)
    }

    @Test func aMicProblemNeedsAMicInUse() {
        let noMic = Snapshot(devices: [.speaker: [speakers]], active: [.speaker: speakers])
        #expect(ReadyCheck.evaluate(noMic, setup: nil, micProblem: .muted).isReady)
    }
}
