import Foundation
import GreenRoomCore

// `greenroom`: checks your camera, mic, and speakers from Terminal. Reads devices directly,
// so it works whether or not the app is running.

let usage = """
    Usage: greenroom <command> [--json]

      status     The camera, mic, and speaker in use, and anything to fix (exits 2 if so)
                 --recording adds camera format, mic quality, disk space, and power,
                 and exits 2 if anything would spoil a recording
      devices    Everything connected, and devices that are usually here but missing
      history    Recent plug-ins, unplugs, and switches (--limit N, default 20)
      setups     Your saved setups, and which one fits what's plugged in
      use NAME   Switch the Mac's mic and speaker to a setup's devices

    """

let json = CommandLine.arguments.contains("--json")
let arguments = CommandLine.arguments.dropFirst().filter { $0 != "--json" }

func option(_ name: String, in arguments: [String]) -> String? {
    guard let index = arguments.firstIndex(of: name), index + 1 < arguments.count else { return nil }
    return arguments[index + 1]
}

func printJSON<T: Encodable>(_ value: T) {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    encoder.dateEncodingStrategy = .iso8601
    if let data = try? encoder.encode(value) { print(String(bytes: data, encoding: .utf8) ?? "") }
}

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data((message + "\n").utf8))
    exit(1)
}

let appDefaults = UserDefaults(suiteName: Storage.defaultsDomain)
let ignoredApps = Set(appDefaults?.stringArray(forKey: "ignoredApps") ?? [])
let snapshot = DeviceScanner.snapshot().ignoring(apps: ignoredApps)
let history = Storage.loadHistory()
let usb = USBDevices.productNames()
let setups = appDefaults.map(Storage.loadSetups) ?? []
let setup = Setup.bestMatch(setups, snapshot: snapshot)

switch arguments.first {
case "status":
    let report = StatusReport.make(
        snapshot: snapshot, setup: setup, history: history, usbProducts: usb,
        micProblem: snapshot.active(.microphone).flatMap(AudioHardware.micProblem), now: .now
    )
    let recording = arguments.contains("--recording") ? RecordingCheck.evaluate(RecordingCheck.currentInputs(
        camera: snapshot.active(.camera) ?? snapshot.devices(.camera).first, mic: snapshot.active(.microphone),
        sampleRates: snapshot.sampleRates
    )) : nil
    if json {
        // The status fields stay at the top level either way; --recording adds one key.
        if let recording,
           let base = try? JSONSerialization.jsonObject(with: JSONEncoder().encode(report)) as? [String: Any],
           let extra = try? JSONSerialization.jsonObject(with: JSONEncoder().encode(recording)) {
            var merged = base
            merged["recording"] = extra
            let data = try? JSONSerialization.data(withJSONObject: merged, options: [.prettyPrinted, .sortedKeys])
            print(data.flatMap { String(bytes: $0, encoding: .utf8) } ?? "{}")
        } else {
            printJSON(report)
        }
    } else {
        print(report.text)
        if let recording {
            print("\nReady to record? \(recording.ready ? "Yes" : "Not yet")")
            for item in recording.items { print("\(item.passed ? "✓" : "!") \(item.title): \(item.detail)") }
        }
    }
    exit(report.ready && recording?.ready != false ? 0 : 2)

case "devices":
    struct Listed: Encodable {
        let kind: DeviceKind, name: String, transport: Transport, connected: Bool, inUse: Bool
        let reason: String?, advice: String?, lastSeen: Date?
    }
    var listed: [Listed] = []
    for kind in DeviceKind.allCases {
        for device in snapshot.devices(kind) {
            listed.append(Listed(
                kind: kind, name: device.name, transport: device.transport, connected: true,
                inUse: snapshot.active(kind)?.id == device.id, reason: nil, advice: nil, lastSeen: nil
            ))
        }
        for record in history.missingUsual(snapshot, now: .now) where record.device.kind == kind {
            let reason = MissingReason.diagnose(
                name: record.device.name, transport: record.device.transport, usbProducts: usb
            )
            listed.append(Listed(
                kind: kind, name: record.device.name, transport: record.device.transport, connected: false,
                inUse: false, reason: reason.headline, advice: reason.advice, lastSeen: record.lastSeen
            ))
        }
    }
    let present = Set(listed.map(\.name))
    for remembered in MacAudioMemory.remembered() where !present.contains(remembered.name) {
        let reason = MissingReason.diagnose(name: remembered.name, transport: .usb, usbProducts: usb)
        listed.append(Listed(
            kind: .microphone, name: remembered.name, transport: .usb, connected: false, inUse: false,
            reason: "Used on this Mac before, \(reason.headline.lowercased())", advice: reason.advice, lastSeen: nil
        ))
    }
    if json {
        printJSON(listed)
    } else {
        let rememberedOnly = listed.filter { $0.reason?.hasPrefix("Used on this Mac") == true }
        for kind in DeviceKind.allCases {
            print(kind.title)
            for item in listed where item.kind == kind && !rememberedOnly.map(\.name).contains(item.name) {
                let mark = item.inUse ? "●" : item.connected ? " " : "!"
                let note = item.reason.map { " · \($0)" } ?? ""
                print("  \(mark) \(item.name) · \(item.transport.label)\(note)")
            }
        }
        if !rememberedOnly.isEmpty {
            print("Used on this Mac before, not connected now")
            for item in rememberedOnly {
                print("  ! \(item.name) · \(item.reason?.components(separatedBy: ", ").last ?? "")")
            }
        }
    }

case "history":
    let limit = option("--limit", in: arguments).flatMap(Int.init) ?? 20
    let events = Array(history.events.suffix(limit).reversed())
    if json {
        printJSON(events)
    } else if events.isEmpty {
        print("Nothing yet. Green Room records plug-ins, unplugs, and switches while it's running.")
    } else {
        for event in events {
            let time = event.time.formatted(date: .abbreviated, time: .shortened)
            let change = event.change.rawValue.padding(toLength: 12, withPad: " ", startingAt: 0)
            print("\(time)  \(change)\(event.device.name)")
        }
    }

case "setups":
    struct Listed: Encodable {
        let name: String, fits: Bool, connected: Int, devices: [String: String]
    }
    let listed = setups.map { item in
        Listed(
            name: item.name, fits: item.name == setup?.name, connected: item.connectedCount(in: snapshot),
            devices: Dictionary(uniqueKeysWithValues: item.devices.map { ($0.key.rawValue, $0.value.name) })
        )
    }
    if json {
        printJSON(listed)
    } else if listed.isEmpty {
        print("No setups saved yet. Open Green Room and click Save as my setup.")
    } else {
        for item in setups {
            let mark = item.name == setup?.name ? "●" : " "
            let names = DeviceKind.allCases.compactMap { item.devices[$0]?.name }
            print("\(mark) \(item.name): \(names.joined(separator: ", "))")
        }
    }

case "use":
    let name = arguments.dropFirst().joined(separator: " ")
    guard let chosen = setups.first(where: { $0.name.localizedCaseInsensitiveCompare(name) == .orderedSame }) else {
        fail("No setup named \"\(name)\". Run `greenroom setups` to see them.")
    }
    var switched: [String] = []
    var missing: [String] = []
    for kind in [DeviceKind.microphone, .speaker] {
        guard let device = chosen.devices[kind] else { continue }
        guard let connected = snapshot.device(device.id, kind: kind) else {
            missing.append(device.name)
            continue
        }
        if AudioHardware.setDefault(connected) {
            switched.append("\(kind.title): \(connected.name)")
        } else {
            missing.append("\(connected.name) (macOS refused the switch)")
        }
    }
    if json {
        printJSON([
            "setup": chosen.name, "switched": switched.joined(separator: "; "),
            "missing": missing.joined(separator: ", ")
        ])
    } else {
        print("Using \(chosen.name).")
        switched.forEach { print("  \($0)") }
        if !missing.isEmpty { print("  Not connected: \(missing.joined(separator: ", "))") }
        // Cameras: each app keeps its own choice, so a command can't set it for them.
        if let camera = chosen.devices[.camera] { print("  Pick \(camera.name) as the camera in your call app.") }
    }
    exit(missing.isEmpty && !switched.isEmpty ? 0 : 2)

case "--version", "-v":
    print(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "dev")

case nil, "help", "--help", "-h":
    print(usage, terminator: "")

default:
    fail("Unknown command: \(arguments[0])\n\n\(usage)")
}
