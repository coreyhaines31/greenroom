import GreenRoomCore

let snapshot = DeviceScanner.snapshot()
for kind in DeviceKind.allCases {
    print(kind.title)
    let active = snapshot.active(kind)?.id
    for device in snapshot.devices(kind) {
        let marker = device.id == active ? "●" : " "
        print("  \(marker) \(device.name) (\(device.transport.label))")
    }
}

let usb = USBDevices.productNames()
let connected = Set(DeviceKind.allCases.flatMap(snapshot.devices).map(\.name))
let missing = MacAudioMemory.remembered().filter { !connected.contains($0.name) }
if !missing.isEmpty {
    print("Used on this Mac before, not connected now")
    for device in missing {
        let reason = MissingReason.diagnose(name: device.name, transport: .usb, usbProducts: usb)
        print("    \(device.name): \(reason.headline). \(reason.advice)")
    }
}
if let mic = snapshot.active(.microphone), let problem = AudioHardware.micProblem(mic) {
    print("Microphone: \(problem.message)")
}
