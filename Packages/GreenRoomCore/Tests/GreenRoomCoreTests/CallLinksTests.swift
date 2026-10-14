@testable import GreenRoomCore
import Testing

struct CallLinksTests {
    @Test func recognizesMeetingLinks() {
        #expect(CallLinks.isVideoCall(["https://us02web.zoom.us/j/123", nil]))
        #expect(CallLinks.isVideoCall([nil, "Join: https://meet.google.com/abc-defg-hij"]))
        #expect(CallLinks.isVideoCall(["Microsoft Teams Meeting", "https://teams.microsoft.com/l/meetup-join/x"]))
        #expect(!CallLinks.isVideoCall(["Dentist", "123 Main St"]))
    }

    @Test func skipsInCallOnlyProblems() {
        let shure = Device(id: "mv7", name: "Shure MV7", kind: .microphone, transport: .usb)
        let mac = Device(id: "mac", name: "MacBook Pro Microphone", kind: .microphone, transport: .builtIn)
        let readiness = Readiness.notReady([
            Mismatch(kind: .microphone, expected: shure, problem: .appUsing(app: "zoom.us", actual: mac)),
            Mismatch(kind: .speaker, expected: shure, problem: .missing)
        ])
        #expect(CallLinks.preCallProblems(readiness: readiness).map(\.problem) == [.missing])
    }
}
