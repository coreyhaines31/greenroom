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

    @Test func unplacedDevicesStartWiredThenBuiltInThenWireless() {
        let iPhone = Device(id: "iphone", name: "iPhone Microphone", kind: .microphone, transport: .continuity)

        let ranked = DevicePriorities().ranked([iPhone, airpods, mac, shure], kind: .microphone)

        #expect(ranked.map(\.id) == ["shure", "mac", "airpods", "iphone"])
    }

    @Test func monitorSpeakersStartBelowTheMacs() {
        let monitor = Device(id: "lg", name: "LG Ultra HD", kind: .speaker, transport: .display)
        let speakers = Device(id: "mac", name: "MacBook Pro Speakers", kind: .speaker, transport: .builtIn)

        #expect(DevicePriorities().ranked([monitor, speakers], kind: .speaker).map(\.id) == ["mac", "lg"])
    }

    @Test func adoptingSavesTheShownOrderOnce() {
        var priorities = DevicePriorities()

        priorities.adopt([airpods, mac], kind: .microphone)
        priorities.adopt([airpods, mac, shure], kind: .microphone)

        #expect(priorities.order[.microphone] == ["mac", "airpods"])
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
