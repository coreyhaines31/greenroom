import Foundation
@testable import GreenRoomCore
import Testing

struct SetupsTests {
    let shure = Device(id: "mv7", name: "Shure MV7", kind: .microphone, transport: .usb)
    let monitors = Device(id: "mon", name: "Studio Monitors", kind: .speaker, transport: .usb)
    let camLink = Device(id: "cam", name: "Cam Link 4K", kind: .camera, transport: .external)
    let macMic = Device(id: "mac", name: "MacBook Pro Microphone", kind: .microphone, transport: .builtIn)
    let pods = Device(id: "pods", name: "AirPods Pro", kind: .speaker, transport: .bluetooth)
    let facetime = Device(id: "ft", name: "MacBook Pro Camera", kind: .camera, transport: .builtIn)

    var desk: Setup { Setup(name: "Desk", devices: [.microphone: shure, .speaker: monitors, .camera: camLink]) }
    var travel: Setup { Setup(name: "Travel", devices: [.microphone: macMic, .speaker: pods, .camera: facetime]) }

    func snapshot(_ devices: [Device]) -> Snapshot {
        Snapshot(devices: Dictionary(grouping: devices, by: \.kind))
    }

    @Test func picksTheSetupWhoseDevicesArePluggedIn() {
        let docked = snapshot([shure, monitors, camLink, macMic, facetime])
        #expect(Setup.bestMatch([travel, desk], snapshot: docked)?.name == "Desk")
        let onTheRoad = snapshot([macMic, facetime, pods])
        #expect(Setup.bestMatch([desk, travel], snapshot: onTheRoad)?.name == "Travel")
    }

    @Test func tiesGoToTheSetupUsedLast() {
        var studio = desk
        studio.name = "Studio"
        studio.lastUsed = Date(timeIntervalSince1970: 2)
        var older = desk
        older.lastUsed = Date(timeIntervalSince1970: 1)
        let docked = snapshot([shure, monitors, camLink])
        #expect(Setup.bestMatch([older, studio], snapshot: docked)?.name == "Studio")
    }

    @Test func loadsTheOneSetupThatEarlierVersionsSaved() throws {
        let defaults = try #require(UserDefaults(suiteName: "SetupsTests-\(UUID().uuidString)"))
        defaults.set(try JSONEncoder().encode(desk), forKey: "setup")
        #expect(Storage.loadSetups(defaults) == [desk])
        Storage.saveSetups([desk, travel], defaults)
        #expect(Storage.loadSetups(defaults).map(\.name) == ["Desk", "Travel"])
        #expect(defaults.data(forKey: "setup") == nil)
    }
}
