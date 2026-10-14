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
