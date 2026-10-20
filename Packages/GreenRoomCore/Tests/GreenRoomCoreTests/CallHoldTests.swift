import Foundation
@testable import GreenRoomCore
import Testing

struct CallHoldTests {
    private let now = Date(timeIntervalSince1970: 1_000)

    @Test func renewsOnlyWhileSignalIsLive() {
        var hold = CallHold()
        #expect(hold.request(active: true, now: now) == "focus:")
        hold.completed("focus:Do Not Disturb", startedAt: now, now: now)
        #expect(hold.request(active: true, now: now.addingTimeInterval(30)) == nil)
        #expect(hold.request(active: true, now: now.addingTimeInterval(45)) == "focus:Do Not Disturb")
        #expect(hold.request(active: false, now: now.addingTimeInterval(60)) == nil)
        #expect(hold.request(active: false, now: now.addingTimeInterval(165)) == nil)
        #expect(hold.request(active: true, now: now.addingTimeInterval(166)) == "focus:")
    }

    @Test func existingOrChangedFocusPausesUntilCallEnds() {
        var hold = CallHold()
        _ = hold.request(active: true, now: now)
        hold.completed("blocked", startedAt: now, now: now)
        #expect(hold.isPaused)
        #expect(hold.request(active: true, now: now.addingTimeInterval(60)) == nil)
        #expect(hold.request(active: false, now: now.addingTimeInterval(180)) == nil)
        #expect(hold.request(active: true, now: now.addingTimeInterval(181)) == "focus:")
    }

    @Test func expiredLeaseDoesNotReclaimFocus() {
        var hold = CallHold()
        _ = hold.request(active: true, now: now)
        hold.completed("focus:Do Not Disturb", startedAt: now, now: now)
        #expect(hold.request(active: true, now: now.addingTimeInterval(121)) == nil)
        #expect(hold.isPaused)
    }

    @Test func failedOrLateShortcutDoesNotClaimOwnership() {
        for result in ["", "focus:", "Error"] {
            var hold = CallHold()
            hold.completed(result, startedAt: now, now: now)
            #expect(hold.isPaused)
            #expect(hold.heldUntil == nil)
        }
        var hold = CallHold()
        hold.completed("focus:Do Not Disturb", startedAt: now, now: now.addingTimeInterval(121))
        #expect(hold.isPaused)
    }

    @Test func onlyOtherAppsMicrophonesAndCamerasCount() {
        var snapshot = Snapshot()
        snapshot.live = [LiveUse(kind: .speaker, deviceID: "speaker", app: "Music")]
        #expect(!CallHold.hasDeviceSignal(snapshot, ignoring: []))
        snapshot.live.append(LiveUse(kind: .microphone, deviceID: "mic", app: "Recorder"))
        #expect(CallHold.hasDeviceSignal(snapshot, ignoring: []))
        #expect(!CallHold.hasDeviceSignal(snapshot, ignoring: ["Recorder"]))
        snapshot.live.append(LiveUse(kind: .camera, deviceID: "camera", app: nil))
        #expect(CallHold.hasDeviceSignal(snapshot, ignoring: ["Recorder"]))
    }

    @Test func ownPreviewDoesNotHoldCallsButOtherDevicesStillDo() {
        var snapshot = Snapshot()
        snapshot.live = [LiveUse(kind: .camera, deviceID: "preview", app: nil)]
        #expect(!CallHold.hasDeviceSignal(
            snapshot, ignoring: [], runningCameras: ["preview"], previewCamera: "preview"
        ))
        #expect(CallHold.hasDeviceSignal(snapshot, ignoring: [], runningCameras: ["other"], previewCamera: "preview"))
        snapshot.live.append(LiveUse(kind: .microphone, deviceID: "mic", app: "Zoom"))
        #expect(CallHold.hasDeviceSignal(snapshot, ignoring: [], runningCameras: ["preview"], previewCamera: "preview"))
    }
}
