import Foundation
@testable import GreenRoomCore
import Testing

struct TakeoverTests {
    let monitors = Device(id: "mon", name: "Studio Monitors", kind: .speaker, transport: .usb)
    let pods = Device(id: "pods-out", name: "AirPods Pro", kind: .speaker, transport: .bluetooth)
    let t0 = Date(timeIntervalSince1970: 1000)

    var setup: Setup { Setup(name: "Desk", devices: [.speaker: monitors]) }
    var podsActive: Snapshot { Snapshot(devices: [.speaker: [monitors, pods]], active: [.speaker: pods]) }

    func event(_ change: DeviceHistory.Change, _ device: Device, after seconds: TimeInterval) -> DeviceHistory.Event {
        DeviceHistory.Event(time: t0.addingTimeInterval(seconds), change: change, device: device)
    }

    @Test func switchesBackWhenANewlyConnectedDeviceTakesOver() {
        let connected = event(.connected, pods, after: 0)
        let selected = event(.selected, pods, after: 2)
        let takeovers = Takeover.detect(
            events: [connected, selected], timeline: [connected, selected], setup: setup, snapshot: podsActive,
            exempt: []
        )
        #expect(takeovers == [Takeover(kind: .speaker, intruder: pods, restore: monitors)])
    }

    @Test func leavesAChoiceYouMadeAlone() {
        // AirPods connected an hour ago; picking them now is a choice, not a takeover.
        let connected = event(.connected, pods, after: 0)
        let selected = event(.selected, pods, after: 3600)
        #expect(Takeover.detect(
            events: [selected], timeline: [connected, selected], setup: setup, snapshot: podsActive, exempt: []
        ).isEmpty)
    }

    @Test func respectsDevicesYouChoseToKeep() {
        let connected = event(.connected, pods, after: 0)
        let selected = event(.selected, pods, after: 1)
        #expect(Takeover.detect(
            events: [selected], timeline: [connected, selected], setup: setup, snapshot: podsActive,
            exempt: ["pods-out"]
        ).isEmpty)
    }

    @Test func doesNothingWhenTheSetupDeviceIsGone() {
        let connected = event(.connected, pods, after: 0)
        let selected = event(.selected, pods, after: 1)
        let unplugged = Snapshot(devices: [.speaker: [pods]], active: [.speaker: pods])
        #expect(Takeover.detect(
            events: [selected], timeline: [connected, selected], setup: setup, snapshot: unplugged, exempt: []
        ).isEmpty)
    }
}
