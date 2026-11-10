@testable import GreenRoomCore
import Testing

struct CallLinksTests {
    @Test func recognizesMeetingLinks() {
        #expect(CallLinks.isVideoCall(["https://us02web.zoom.us/j/123", nil]))
        #expect(CallLinks.isVideoCall([nil, "Join: https://meet.google.com/abc-defg-hij"]))
        #expect(CallLinks.isVideoCall(["Microsoft Teams Meeting", "https://teams.microsoft.com/l/meetup-join/x"]))
        #expect(!CallLinks.isVideoCall(["Dentist", "123 Main St"]))
    }

    @Test func skipsCallsYouWontJoin() {
        let zoom = ["https://us02web.zoom.us/j/123"]
        #expect(CallLinks.isCallToJoin(isAllDay: false, isCanceled: false, isDeclined: false, texts: zoom))
        #expect(!CallLinks.isCallToJoin(isAllDay: false, isCanceled: true, isDeclined: false, texts: zoom))
        #expect(!CallLinks.isCallToJoin(isAllDay: false, isCanceled: false, isDeclined: true, texts: zoom))
        #expect(!CallLinks.isCallToJoin(isAllDay: true, isCanceled: false, isDeclined: false, texts: zoom))
        #expect(!CallLinks.isCallToJoin(isAllDay: false, isCanceled: false, isDeclined: false, texts: ["Dentist"]))
    }

    @Test func skipsInCallOnlyProblems() {
        let shure = Device(id: "mv7", name: "Shure MV7", kind: .microphone, transport: .usb)
        let mac = Device(id: "mac", name: "MacBook Pro Microphone", kind: .microphone, transport: .builtIn)
        let check = ReadyCheck(readiness: .notReady([
            Mismatch(kind: .microphone, expected: shure, problem: .appUsing(app: "zoom.us", actual: mac)),
            Mismatch(kind: .speaker, expected: shure, problem: .missing)
        ]))
        #expect(CallLinks.preCallProblems(check).map(\.sentence) == ["Shure MV7 isn't connected."])
    }

    @Test func warnsAboutAMutedMicBeforeACall() {
        let mac = Device(id: "mac", name: "MacBook Pro Microphone", kind: .microphone, transport: .builtIn)
        let snapshot = Snapshot(devices: [.microphone: [mac]], active: [.microphone: mac])
        let matching = ReadyCheck.evaluate(snapshot, setup: .current(snapshot, name: "Desk"), micProblem: .muted)
        #expect(CallLinks.preCallProblems(matching).map(\.sentence) == [MicProblem.muted.message])
        // With no setup saved, a muted mic still gets the heads-up.
        let noSetup = ReadyCheck.evaluate(snapshot, setup: nil, micProblem: .volumeZero)
        #expect(CallLinks.preCallProblems(noSetup).map(\.sentence) == [MicProblem.volumeZero.message])
    }
}
