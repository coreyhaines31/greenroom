import Foundation
@testable import GreenRoomCore
import Testing

struct FlakyTests {
    let shure = Device(id: "mv7", name: "Shure MV7", kind: .microphone, transport: .usb)
    let cam = Device(id: "cam", name: "Cam Link 4K", kind: .camera, transport: .external)
    let mon = Device(id: "mon", name: "Studio Monitors", kind: .speaker, transport: .usb)
    let start = Date(timeIntervalSince1970: 1_760_000_000)

    /// Unplugs `device` at each offset and plugs it back `away` seconds later.
    func history(_ device: Device, at offsets: [TimeInterval], away: TimeInterval) -> DeviceHistory {
        var history = DeviceHistory()
        let all = [shure, cam, mon]
        let docked = Snapshot(devices: Dictionary(grouping: all, by: \.kind))
        let without = Snapshot(devices: Dictionary(grouping: all.filter { $0 != device }, by: \.kind))
        history.update(docked, now: start)
        for offset in offsets {
            history.update(without, now: start.addingTimeInterval(offset))
            history.update(docked, now: start.addingTimeInterval(offset + away))
        }
        return history
    }

    @Test func flagsADeviceThatKeepsBlipping() {
        let flaky = FlakyDevice.find(
            in: history(shure, at: [3600, 7200, 10800], away: 4), now: start.addingTimeInterval(86400)
        )
        #expect(flaky.map(\.message) == ["Shure MV7 dropped out and came back 3 times this week"])
    }

    @Test func unpluggingOnPurposeDoesntCount() {
        // Unplugged every evening, back the next morning.
        let nightly = (0..<6).map { Double($0) * 86400 + 64800 }
        #expect(FlakyDevice.find(in: history(shure, at: nightly, away: 50000), now: start.addingTimeInterval(7 * 86400))
            .isEmpty)
    }

    @Test func wholeDockBlipsDontCount() {
        var history = DeviceHistory()
        let all = [shure, cam, mon]
        let docked = Snapshot(devices: Dictionary(grouping: all, by: \.kind))
        history.update(docked, now: start)
        for hour in 1...4 {
            let time = start.addingTimeInterval(Double(hour) * 3600)
            history.update(Snapshot(), now: time)
            history.update(docked, now: time.addingTimeInterval(3))
        }
        #expect(FlakyDevice.find(in: history, now: start.addingTimeInterval(86400)).isEmpty)
    }
}
