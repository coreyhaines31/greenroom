@testable import GreenRoomCore
import Testing

struct RecordingAppsTests {
    @Test func spotsRecordersStartingTheMic() {
        let idle = Snapshot(live: [LiveUse(kind: .microphone, deviceID: "mac", app: "zoom.us")])
        let recording = Snapshot(live: [
            LiveUse(kind: .microphone, deviceID: "mac", app: "zoom.us"),
            LiveUse(kind: .microphone, deviceID: "mv7", app: "Loom")
        ])
        #expect(RecordingApps.started(before: idle, after: recording) == ["Loom"])
        #expect(RecordingApps.started(before: recording, after: recording).isEmpty)
        #expect(!RecordingApps.isRecorder("zoom.us"))
        #expect(RecordingApps.isRecorder("OBS"))
    }
}
