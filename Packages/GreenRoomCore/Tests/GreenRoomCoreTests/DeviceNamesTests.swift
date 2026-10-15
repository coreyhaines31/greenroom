import Foundation
@testable import GreenRoomCore
import Testing

struct DeviceNamesTests {
    let usbMic = Device(id: "usb-1", name: "USB Audio Device", kind: .microphone, transport: .usb)
    let macMic = Device(id: "mac", name: "MacBook Pro Microphone", kind: .microphone, transport: .builtIn)

    @Test func renamesDevicesAndTheActiveOne() {
        var names = DeviceNames()
        names.setNickname("Lapel mic", for: "usb-1")
        let snapshot = Snapshot(devices: [.microphone: [usbMic, macMic]], active: [.microphone: usbMic])

        let named = names.apply(snapshot)

        #expect(named.devices(.microphone).map(\.name) == ["Lapel mic", "MacBook Pro Microphone"])
        #expect(named.active(.microphone)?.name == "Lapel mic")
        #expect(named.active(.microphone)?.id == "usb-1")
    }

    @Test func blankNameGoesBackToTheSystemName() {
        var names = DeviceNames()
        names.setNickname("Lapel mic", for: "usb-1")
        names.setNickname("   ", for: "usb-1")

        #expect(names.nicknames.isEmpty)
        #expect(names.apply(usbMic).name == "USB Audio Device")
    }

    @Test func setupsShowTheCurrentName() {
        var names = DeviceNames()
        names.setNickname("Lapel mic", for: "usb-1")
        let setup = Setup(name: "Desk", devices: [.microphone: usbMic])

        #expect(names.apply(setup).devices[.microphone]?.name == "Lapel mic")
    }

    @Test func roundTripsThroughDefaults() throws {
        let defaults = try #require(UserDefaults(suiteName: "DeviceNamesTests"))
        defer { defaults.removePersistentDomain(forName: "DeviceNamesTests") }
        let names = DeviceNames(nicknames: ["usb-1": "Lapel mic"], hidden: ["mac"])

        names.save(defaults)

        #expect(DeviceNames.load(defaults) == names)
        #expect(DeviceNames.load(defaults).isHidden(macMic))
    }
}
