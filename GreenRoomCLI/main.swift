import Foundation
import GreenRoomCore

// `greenroom`: checks your camera, mic, and speakers from Terminal. Reads devices directly,
// so it works whether or not the app is running.

let usage = """
    Usage: greenroom <command> [--json]

      status     The camera, mic, and speaker in use, and anything to fix (exits 2 if so)
      devices    Everything connected, and devices that are usually here but missing
      history    Recent plug-ins, unplugs, and switches (--limit N, default 20)

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

let snapshot = DeviceScanner.snapshot()
let history = Storage.loadHistory()
let usb = USBDevices.productNames()
let setup = UserDefaults(suiteName: Storage.defaultsDomain).flatMap(Storage.loadSetup)

switch arguments.first {
case "status":
    let report = StatusReport.make(
        snapshot: snapshot, setup: setup, history: history, usbProducts: usb,
        micProblem: snapshot.active(.microphone).flatMap(AudioHardware.micProblem), now: .now
    )
    if json { printJSON(report) } else { print(report.text) }
    exit(report.ready ? 0 : 2)

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

case "--version", "-v":
    print(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "dev")

case nil, "help", "--help", "-h":
    print(usage, terminator: "")

default:
    fail("Unknown command: \(arguments[0])\n\n\(usage)")
}
