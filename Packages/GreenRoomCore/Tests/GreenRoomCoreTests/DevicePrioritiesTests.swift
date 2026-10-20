import Foundation
@testable import GreenRoomCore
import Testing

struct DevicePrioritiesTests {
    let shure = Device(id: "shure", name: "Shure MV7", kind: .microphone, transport: .usb)
    let mac = Device(id: "mac", name: "MacBook Pro Microphone", kind: .microphone, transport: .builtIn)
    let airpods = Device(id: "airpods", name: "AirPods Pro", kind: .microphone, transport: .bluetooth)

    @Test func unplacedDevicesFollowYourOrder() {
        let priorities = DevicePriorities(order: [.microphone: ["shure"]])

        let ranked = priorities.ranked([mac, airpods, shure], kind: .microphone)

        #expect(ranked.map(\.id) == ["shure", "mac", "airpods"])
    }

    @Test func movingSavesTheWholeShownOrder() {
        var priorities = DevicePriorities()

        priorities.move(airpods, by: -1, among: [shure, mac, airpods])

        #expect(priorities.order[.microphone] == ["shure", "airpods", "mac"])
    }

    @Test func movingKeepsDevicesThatArentListed() {
        var priorities = DevicePriorities(order: [.microphone: ["shure", "old-usb", "mac"]])

        priorities.move(mac, by: -1, among: [shure, mac])

        #expect(priorities.order[.microphone] == ["mac", "shure", "old-usb"])
    }

    @Test func movingPastTheEndDoesNothing() {
        var priorities = DevicePriorities(order: [.microphone: ["shure", "mac"]])

        priorities.move(shure, by: -1, among: [shure, mac])

        #expect(priorities.order[.microphone] == ["shure", "mac"])
    }

    @Test func bestIsTheHighestConnectedDevice() {
        let priorities = DevicePriorities(order: [.microphone: ["shure", "mac", "airpods"]])
        let snapshot = Snapshot(devices: [.microphone: [airpods, mac]], active: [.microphone: airpods])

        #expect(priorities.best(.microphone, in: snapshot)?.id == "mac")
    }

    @Test func noBestUntilYouOrderThatKind() {
        let priorities = DevicePriorities(order: [.speaker: ["studio"]])
        let snapshot = Snapshot(devices: [.microphone: [mac]], active: [:])

        #expect(priorities.best(.microphone, in: snapshot) == nil)
    }

    @Test func noBestWhenNoneOfYoursIsConnected() {
        let priorities = DevicePriorities(order: [.microphone: ["shure"]])
        let snapshot = Snapshot(devices: [.microphone: [airpods]], active: [:])

        #expect(priorities.best(.microphone, in: snapshot) == nil)
    }
}
