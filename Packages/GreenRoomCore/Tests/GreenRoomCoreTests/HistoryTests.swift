import Foundation
@testable import GreenRoomCore
import Testing

struct HistoryTests {
    let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        return calendar
    }()
    let start = Date(timeIntervalSince1970: 1_760_457_600) // 2025-10-14 09:00 PDT
    let mic = Device(id: "atr", name: "ATR2100x-USB Microphone", kind: .microphone, transport: .usb)
    let pods = Device(id: "pods", name: "AirPods Pro", kind: .microphone, transport: .bluetooth)
    let builtIn = Device(id: "mac", name: "MacBook Pro Microphone", kind: .microphone, transport: .builtIn)

    func snapshot(_ mics: [Device], active: Device?) -> Snapshot {
        Snapshot(devices: [.microphone: mics], active: active.map { [.microphone: $0] } ?? [:])
    }

    func day(_ offset: Int, hour: Int = 0) -> Date {
        start.addingTimeInterval(TimeInterval(offset * 86400 + hour * 3600))
    }

    @Test func firstRunRecordsDevicesWithoutEvents() {
        var history = DeviceHistory()
        history.update(snapshot([mic, builtIn], active: mic), now: start, calendar: calendar)
        #expect(history.events.isEmpty)
        #expect(history.record(for: mic)?.days == ["2025-10-14"])
    }

    @Test func recordsUnplugPlugAndSwitch() {
        var history = DeviceHistory()
        history.update(snapshot([mic, builtIn], active: mic), now: start, calendar: calendar)
        history.update(snapshot([builtIn], active: builtIn), now: day(0, hour: 1), calendar: calendar)
        history.update(snapshot([builtIn, pods], active: pods), now: day(0, hour: 2), calendar: calendar)
        let changes = history.events.map { "\($0.change.rawValue) \($0.device.id)" }
        #expect(changes == ["disconnected atr", "selected mac", "connected pods", "selected pods"])
    }

    @Test func unchangedSnapshotRecordsNoEvents() {
        var history = DeviceHistory()
        history.update(snapshot([mic], active: mic), now: start, calendar: calendar)
        // Same day, same devices: only lastSeen moves.
        history.update(snapshot([mic], active: mic), now: day(0, hour: 1), calendar: calendar)
        #expect(history.events.isEmpty)
    }

    @Test func usualMeansSeenOnMostRecentDays() {
        var history = DeviceHistory()
        for offset in 0..<5 {
            let mics = offset == 2 ? [builtIn, mic, pods] : [builtIn, mic]
            history.update(snapshot(mics, active: mic), now: day(offset), calendar: calendar)
        }
        let now = day(5)
        history.update(snapshot([builtIn], active: builtIn), now: now, calendar: calendar)
        // The ATR was here 5 days running and is gone now; AirPods showed up once.
        #expect(history.missingUsual(snapshot([builtIn], active: builtIn), now: now, calendar: calendar)
            .map(\.device.id) == ["atr"])
    }

    @Test func onTheFirstDayEverythingSeenIsUsual() {
        var history = DeviceHistory()
        history.update(snapshot([builtIn, mic], active: mic), now: start, calendar: calendar)
        let later = snapshot([builtIn], active: builtIn)
        history.update(later, now: day(0, hour: 3), calendar: calendar)
        #expect(history.missingUsual(later, now: day(0, hour: 3), calendar: calendar).map(\.device.id) == ["atr"])
    }

    @Test func stopsBeingUsualAfterTwoWeeksAway() {
        var history = DeviceHistory()
        for offset in 0..<3 {
            history.update(snapshot([builtIn, mic], active: mic), now: day(offset), calendar: calendar)
        }
        for offset in 3..<20 {
            history.update(snapshot([builtIn], active: builtIn), now: day(offset), calendar: calendar)
        }
        #expect(history.missingUsual(snapshot([builtIn], active: builtIn), now: day(19), calendar: calendar).isEmpty)
    }

    @Test func roundTripsThroughJSON() throws {
        var history = DeviceHistory()
        history.update(snapshot([mic], active: mic), now: start, calendar: calendar)
        history.update(snapshot([], active: nil), now: day(1), calendar: calendar)
        let data = try JSONEncoder().encode(history)
        #expect(try JSONDecoder().decode(DeviceHistory.self, from: data) == history)
    }
}

struct DiagnosisTests {
    @Test func tellsUnpluggedFromNotWorking() {
        let usb = ["USB2.0 Hub", "Stream Deck Pedal", "Pebble V3"]
        #expect(MissingReason.diagnose(name: "ATR2100x-USB Microphone", transport: .usb, usbProducts: usb) == .notOnUSB)
        #expect(MissingReason.diagnose(
            name: "ATR2100x-USB Microphone", transport: .usb, usbProducts: usb + ["ATR2100x-USB"]
        ) == .onUSBButNotWorking)
        #expect(MissingReason.diagnose(name: "AirPods Pro", transport: .bluetooth, usbProducts: usb)
            == .bluetoothNotConnected)
    }

    @Test func matchesUSBNamesLoosely() {
        #expect(USBDevices.matches("Cam Link 4K", in: ["Cam Link 4K"]))
        #expect(USBDevices.matches("Shure MV7+", in: ["Shure MV7+ "]))
        #expect(!USBDevices.matches("Cam Link 4K", in: ["Camera Hub"]))
    }

    @Test func readsDevicesMacOSRemembers() throws {
        let plist: [String: Any] = [
            "device.AppleUSBAudioEngine:Audio Technica Crop:ATR2100x-USB Microphone:12345678ABCD:2,1": [:],
            "device.AppleUSBAudioEngine:Audio Technica Crop:ATR2100x-USB Microphone:12345678ABCD:3,1": [:],
            "device.AppleUSBAudioEngine:Opal:Opal C1:14442C10A1988FD700:2": [:],
            "device.BuiltInMicrophoneDevice": [:],
            "device.74-3F-8E-B6-C0-6B:input": [:]
        ]
        let data = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
        #expect(MacAudioMemory.remembered(fromPlist: data).map(\.name) == ["ATR2100x-USB Microphone", "Opal C1"])
    }
}
