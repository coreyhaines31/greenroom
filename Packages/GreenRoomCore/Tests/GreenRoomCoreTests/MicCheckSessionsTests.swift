@testable import GreenRoomCore
import Testing

struct MicCheckSessionsTests {
    let cameraMic = Device(id: "camera", name: "Cam Link", kind: .microphone, transport: .usb)
    let builtIn = Device(id: "mac", name: "Mac microphone", kind: .microphone, transport: .builtIn)
    let monologue = LiveUse(kind: .microphone, deviceID: "camera", app: "Monologue")
    let claude = LiveUse(kind: .microphone, deviceID: "camera", app: "Claude")

    func snapshot(_ live: [LiveUse]) -> Snapshot {
        Snapshot(devices: [.microphone: [cameraMic, builtIn]], active: [.microphone: builtIn], live: live)
    }

    @Test func checksTheAppsDeviceInsteadOfTheDefault() {
        var sessions = MicCheckSessions()
        sessions.reconcile(snapshot([monologue]), ignoring: [], now: 0)
        #expect(sessions.pendingDeviceIDs == ["camera"])
        sessions.observe(["mac": 0.8, "camera": 0], now: 4)
        #expect(sessions.checks[monologue]?.result == .silent)
        #expect(sessions.pendingDeviceIDs.isEmpty)
    }

    @Test func releasingTheMicCancelsChecksAndNextDictationStartsFresh() {
        var sessions = MicCheckSessions()
        sessions.reconcile(snapshot([monologue]), ignoring: [], now: 0)
        sessions.reconcile(snapshot([]), ignoring: [], now: 2)
        sessions.observe([:], now: 4)
        #expect(sessions.checks.isEmpty)
        sessions.reconcile(snapshot([monologue]), ignoring: [], now: 5)
        sessions.observe(["camera": 0.5], now: 6)
        #expect(sessions.checks[monologue]?.result == .soundDetected)
    }

    @Test func anotherAppStartsItsOwnCheckOnASharedMic() {
        var sessions = MicCheckSessions()
        sessions.reconcile(snapshot([monologue]), ignoring: [], now: 0)
        sessions.observe(["camera": 0.5], now: 1)
        sessions.reconcile(snapshot([monologue, claude]), ignoring: [], now: 10)
        #expect(sessions.pendingDeviceIDs == ["camera"])
        sessions.observe(["camera": 0], now: 14)
        #expect(sessions.checks[monologue]?.result == .soundDetected)
        #expect(sessions.checks[claude]?.result == .silent)
    }

    @Test func ignoringAnAppAndSwitchingDevicesCancelsTheOldCheck() {
        var sessions = MicCheckSessions()
        sessions.reconcile(snapshot([monologue, claude]), ignoring: ["Monologue"], now: 0)
        #expect(sessions.checks[monologue] == nil)
        let switched = LiveUse(kind: .microphone, deviceID: "mac", app: "Claude")
        sessions.reconcile(snapshot([switched]), ignoring: [], now: 1)
        #expect(sessions.checks[claude] == nil)
        #expect(sessions.pendingDeviceIDs == ["mac"])
    }
}
