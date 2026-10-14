import Foundation
@testable import GreenRoomCore
import Testing

struct LiveTests {
    let shure = Device(id: "mv7", name: "Shure MV7", kind: .microphone, transport: .usb)
    let macMic = Device(id: "mac", name: "MacBook Pro Microphone", kind: .microphone, transport: .builtIn)
    let podsMic = Device(id: "pods-in", name: "AirPods Pro", kind: .microphone, transport: .bluetooth)
    let pebble = Device(id: "pebble", name: "Pebble V3", kind: .speaker, transport: .usb)
    let podsOut = Device(id: "pods-out", name: "AirPods Pro", kind: .speaker, transport: .bluetooth)

    var setup: Setup { Setup(name: "Desk", devices: [.microphone: shure, .speaker: pebble]) }

    func snapshot(active: [DeviceKind: Device], live: [LiveUse] = [], rates: [String: Double] = [:]) -> Snapshot {
        Snapshot(
            devices: [.microphone: [shure, macMic, podsMic], .speaker: [pebble, podsOut]],
            active: active, live: live, sampleRates: rates
        )
    }

    @Test func flagsTheDeviceAnAppIsReallyUsing() {
        // The defaults match the setup, but Zoom picked the MacBook mic itself.
        let now = snapshot(
            active: [.microphone: shure, .speaker: pebble],
            live: [LiveUse(kind: .microphone, deviceID: "mac", app: "zoom.us")]
        )
        guard case .notReady(let issues) = Readiness.evaluate(now, setup: setup) else {
            Issue.record("expected notReady")
            return
        }
        #expect(issues.map(\.message) == ["zoom.us is using MacBook Pro Microphone, not Shure MV7"])
        // Shure is already the default, so a fix button wouldn't change anything.
        #expect(issues.first?.fix == nil)
        #expect(issues.first?.advice == "Pick Shure MV7 in zoom.us's audio settings.")
    }

    @Test func offersTheSetupDeviceAsTheFix() {
        let now = snapshot(
            active: [.microphone: podsMic, .speaker: podsOut],
            live: [LiveUse(kind: .speaker, deviceID: "pods-out", app: "Google Chrome")]
        )
        guard case .notReady(let issues) = Readiness.evaluate(now, setup: setup) else {
            Issue.record("expected notReady")
            return
        }
        #expect(issues.map(\.message) == [
            "Microphone is AirPods Pro, not Shure MV7",
            "Google Chrome is using AirPods Pro, not Pebble V3"
        ])
        #expect(issues.map(\.fix) == [shure, pebble])
    }

    @Test func readyWhenAppsUseTheSetup() {
        let now = snapshot(
            active: [.microphone: shure, .speaker: pebble],
            live: [LiveUse(kind: .microphone, deviceID: "mv7", app: "zoom.us")]
        )
        #expect(Readiness.evaluate(now, setup: setup) == .ready)
    }

    @Test func warnsWhenABluetoothMicIsInCallMode() {
        let now = snapshot(
            active: [.microphone: podsMic, .speaker: podsOut],
            live: [LiveUse(kind: .microphone, deviceID: "pods-in", app: "Google Chrome")],
            rates: ["pods-in": 24_000, "mac": 96_000]
        )
        let advisories = Advisory.evaluate(now)
        #expect(advisories.map(\.title) == ["AirPods Pro is in call mode"])
        #expect(advisories.first?.fix == macMic)
        #expect(advisories.first?.message.hasPrefix("Google Chrome turned on its mic") == true)
    }

    @Test func quietWhenTheHeadsetMicIsOff() {
        let now = snapshot(active: [.microphone: podsMic, .speaker: podsOut], rates: ["pods-in": 24_000])
        #expect(Advisory.evaluate(now).isEmpty)
    }

    @Test func namesHelpersAfterTheirApp() {
        let helper = "/Applications/Google Chrome.app/Contents/Frameworks/Google Chrome Framework.framework/"
            + "Versions/155/Helpers/Google Chrome Helper.app/Contents/MacOS/Google Chrome Helper"
        #expect(LiveDevices.appName(executablePath: helper) == "Google Chrome")
        #expect(LiveDevices.appName(executablePath: "/usr/sbin/coreaudiod") == "coreaudiod")
    }

    @Test func proposesTheDevicesUsedMostOften() {
        let calendar = Calendar(identifier: .gregorian)
        let start = Date(timeIntervalSince1970: 1_760_457_600)
        var history = DeviceHistory()
        for day in 0..<5 {
            let mics = day == 2 ? [shure, macMic, podsMic] : [shure, macMic]
            history.update(
                Snapshot(
                    devices: [.microphone: mics, .speaker: [pebble]], active: [.microphone: shure, .speaker: pebble]
                ),
                now: start.addingTimeInterval(Double(day) * 86400), calendar: calendar
            )
        }
        // Today the Shure is unplugged and AirPods are the default.
        // The Shure is still the usual mic.
        let today = Snapshot(
            devices: [.microphone: [macMic, podsMic], .speaker: [pebble, podsOut]],
            active: [.microphone: podsMic, .speaker: podsOut]
        )
        let proposal = Setup.proposed(
            history: history, snapshot: today, now: start.addingTimeInterval(5 * 86400), calendar: calendar
        )
        #expect(proposal.devices[.microphone] == shure)
        #expect(proposal.devices[.speaker] == pebble)
    }
}

struct LiveStatusReportTests {
    @Test func reportsLiveAppsAndCallMode() {
        let pods = Device(id: "pods-in", name: "AirPods Pro", kind: .microphone, transport: .bluetooth)
        let macMic = Device(id: "mac", name: "MacBook Pro Microphone", kind: .microphone, transport: .builtIn)
        let snapshot = Snapshot(
            devices: [.microphone: [pods, macMic]], active: [.microphone: pods],
            live: [LiveUse(kind: .microphone, deviceID: "pods-in", app: "Google Chrome")],
            sampleRates: ["pods-in": 16_000]
        )
        let report = StatusReport.make(
            snapshot: snapshot, setup: nil, history: DeviceHistory(), usbProducts: [], micProblem: nil, now: .now
        )
        #expect(!report.ready)
        #expect(report.inUse.first?.liveIn == ["Google Chrome"])
        #expect(report.problems.map(\.message) == ["AirPods Pro is in call mode"])
        #expect(report.text.contains("AirPods Pro · Bluetooth · live in Google Chrome"))
    }
}

struct IgnoreTests {
    let shure = Device(id: "mv7", name: "Shure MV7", kind: .microphone, transport: .usb)
    let macMic = Device(id: "mac", name: "MacBook Pro Microphone", kind: .microphone, transport: .builtIn)
    let zoomAudio = Device(id: "zoom", name: "ZoomAudioDevice", kind: .speaker, transport: .virtual)
    let pebble = Device(id: "pebble", name: "Pebble V3", kind: .speaker, transport: .usb)

    @Test func ignoredAppsAndVirtualDevicesDontCount() {
        let setup = Setup(name: "Desk", devices: [.microphone: shure, .speaker: pebble])
        let snapshot = Snapshot(
            devices: [.microphone: [shure, macMic], .speaker: [pebble, zoomAudio]],
            active: [.microphone: shure, .speaker: pebble],
            live: [
                LiveUse(kind: .microphone, deviceID: "mac", app: "screenpipe"),
                LiveUse(kind: .speaker, deviceID: "zoom", app: "zoom.us")
            ]
        )
        #expect(Readiness.evaluate(snapshot, setup: setup) != .ready)
        #expect(Readiness.evaluate(snapshot.ignoring(apps: ["screenpipe"]), setup: setup) == .ready)
    }
}

struct SystemServiceTests {
    @Test func skipsMacOSSoundServicesButNotApps() {
        #expect(LiveDevices.isSystemService("/System/Library/CoreServices/SystemSoundServer-macOS.app/x"))
        #expect(!LiveDevices.isSystemService("/System/Applications/FaceTime.app/Contents/MacOS/FaceTime"))
        #expect(LiveDevices.isSystemService("/usr/libexec/systemsoundserverd"))
        #expect(LiveDevices.isSystemService("/System/Library/PrivateFrameworks/X.framework/coreaudiod"))
        #expect(!LiveDevices.isSystemService("/opt/homebrew/bin/ffmpeg"))
        #expect(!LiveDevices.isSystemService("/Applications/zoom.us.app/Contents/MacOS/zoom.us"))
    }
}
