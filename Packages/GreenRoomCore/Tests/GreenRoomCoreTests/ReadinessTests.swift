import CoreAudio
@testable import GreenRoomCore
import Testing

struct ReadinessTests {
    let camera = Device(id: "cam", name: "ZV-E10", kind: .camera, transport: .external)
    let facetime = Device(id: "ft", name: "FaceTime HD Camera", kind: .camera, transport: .builtIn)
    let shure = Device(id: "mv7", name: "Shure MV7", kind: .microphone, transport: .usb)
    let macMic = Device(id: "mac-mic", name: "MacBook Pro Microphone", kind: .microphone, transport: .builtIn)
    let monitors = Device(id: "mon", name: "Studio Monitors", kind: .speaker, transport: .usb)
    let airpods = Device(id: "pods", name: "AirPods Pro", kind: .speaker, transport: .bluetooth)

    var studio: Setup {
        Setup(name: "Studio", devices: [.camera: camera, .microphone: shure, .speaker: monitors])
    }

    func snapshot(cameras: [Device], mics: [Device], speakers: [Device], active: [DeviceKind: Device]) -> Snapshot {
        Snapshot(devices: [.camera: cameras, .microphone: mics, .speaker: speakers], active: active)
    }

    @Test func noSetupWithoutSavedDevices() {
        let now = snapshot(cameras: [camera], mics: [shure], speakers: [monitors], active: [:])
        #expect(Readiness.evaluate(now, setup: nil) == .noSetup)
        #expect(Readiness.evaluate(now, setup: Setup(name: "Empty", devices: [:])) == .noSetup)
    }

    @Test func readyWhenEverythingMatches() {
        let now = snapshot(
            cameras: [camera, facetime], mics: [shure, macMic], speakers: [monitors],
            active: [.camera: facetime, .microphone: shure, .speaker: monitors]
        )
        // The camera only has to be connected; call apps choose their own.
        #expect(Readiness.evaluate(now, setup: studio) == .ready)
    }

    @Test func flagsMissingAndSwitchedDevices() {
        let now = snapshot(
            cameras: [facetime], mics: [shure, macMic], speakers: [monitors, airpods],
            active: [.camera: facetime, .microphone: macMic, .speaker: airpods]
        )
        guard case .notReady(let issues) = Readiness.evaluate(now, setup: studio) else {
            Issue.record("expected notReady")
            return
        }
        #expect(issues.map(\.message) == [
            "ZV-E10 isn't connected",
            "Microphone is MacBook Pro Microphone, not Shure MV7",
            "Sound is going to AirPods Pro, not Studio Monitors"
        ])
    }

    @Test func savesActiveDevicesAsSetup() {
        let now = snapshot(
            cameras: [camera], mics: [shure], speakers: [monitors],
            active: [.camera: camera, .microphone: shure, .speaker: monitors]
        )
        #expect(Setup.current(now, name: "Studio") == studio)
    }

    @Test func mapsCoreAudioTransports() {
        #expect(AudioHardware.transport(kAudioDeviceTransportTypeBluetoothLE) == .bluetooth)
        #expect(AudioHardware.transport(kAudioDeviceTransportTypeDisplayPort) == .display)
        #expect(AudioHardware.transport(0) == .other)
    }
}
