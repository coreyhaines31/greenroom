import Foundation
@testable import GreenRoomCore
import Testing

struct FlakyTests {
    let shure = Device(id: "mv7", name: "Shure MV7", kind: .microphone, transport: .usb)
    let cam = Device(id: "cam", name: "Cam Link 4K", kind: .camera, transport: .external)
    let mon = Device(id: "mon", name: "Studio Monitors", kind: .speaker, transport: .usb)
    let start = Date(timeIntervalSince1970: 1_760_000_000)

    func history(_ drops: [(Device, TimeInterval)]) -> DeviceHistory {
        var history = DeviceHistory()
        let all = [shure, cam, mon]
        history.update(Snapshot(devices: Dictionary(grouping: all, by: \.kind)), now: start)
        for (device, offset) in drops.sorted(by: { $0.1 < $1.1 }) {
            let without = all.filter { $0 != device }
            let gone = Snapshot(devices: Dictionary(grouping: without, by: \.kind))
            let back = Snapshot(devices: Dictionary(grouping: all, by: \.kind))
            history.update(gone, now: start.addingTimeInterval(offset))
            history.update(back, now: start.addingTimeInterval(offset + 60))
        }
        return history
    }

    @Test func flagsADeviceThatKeepsDropping() {
        let flaky = FlakyDevice.find(
            in: history((0..<6).map { (shure, Double($0) * 3600) }), now: start.addingTimeInterval(86400)
        )
        #expect(flaky.map(\.message) == ["Shure MV7 disconnected 6 times this week"])
        #expect(flaky.first?.advice.hasPrefix("Try another cable") == true)
    }

    @Test func ignoresAFewDropsAndOldOnes() {
        #expect(FlakyDevice.find(in: history((0..<3).map { (shure, Double($0) * 3600) }), now: start).isEmpty)
        #expect(FlakyDevice.find(
            in: history((0..<6).map { (shure, Double($0) * 3600) }), now: start.addingTimeInterval(30 * 86400)
        ).isEmpty)
    }

    @Test func dockUnplugsDontCount() {
        var history = DeviceHistory()
        let all = [shure, cam, mon]
        history.update(Snapshot(devices: Dictionary(grouping: all, by: \.kind)), now: start)
        for day in 0..<6 {
            let morning = start.addingTimeInterval(Double(day) * 86400)
            history.update(Snapshot(), now: morning.addingTimeInterval(100))
            let docked = Snapshot(devices: Dictionary(grouping: all, by: \.kind))
            history.update(docked, now: morning.addingTimeInterval(200))
        }
        #expect(FlakyDevice.find(in: history, now: start.addingTimeInterval(6 * 86400)).isEmpty)
    }
}
