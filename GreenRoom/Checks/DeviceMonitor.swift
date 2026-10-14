import AVFoundation
import GreenRoomCore
import Observation

/// Keeps a live snapshot of connected devices and checks it against the saved setup.
@MainActor
@Observable
final class DeviceMonitor {
    private(set) var snapshot = Snapshot()
    private(set) var setup: Setup? = SetupStore.load()
    private(set) var history = HistoryStore.load()
    private(set) var usbProducts: [String] = []
    private(set) var remembered: [MacAudioMemory.Remembered] = []
    private(set) var micProblem: MicProblem?

    var readiness: Readiness { Readiness.evaluate(snapshot, setup: setup) }

    @ObservationIgnored var onChange: (() -> Void)?
    /// New timeline events from each device change, for alerts.
    @ObservationIgnored var onEvents: (([DeviceHistory.Event]) -> Void)?
    @ObservationIgnored private var audioListener: AudioChangeListener?
    @ObservationIgnored private var observers: [NSObjectProtocol] = []
    @ObservationIgnored private var dayTimer: Timer?

    func start() {
        let listener = AudioChangeListener { [weak self] in self?.refresh() }
        listener.start()
        audioListener = listener
        for name in [AVCaptureDevice.wasConnectedNotification, AVCaptureDevice.wasDisconnectedNotification] {
            observers.append(NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) { _ in
                MainActor.assumeIsolated { [weak self] in self?.refresh() }
            })
        }
        // Keeps "seen today" right for devices that stay plugged in for days.
        dayTimer = Timer.scheduledTimer(withTimeInterval: 30 * 60, repeats: true) { _ in
            MainActor.assumeIsolated { [weak self] in self?.recordHistory() }
        }
        refresh(force: true)
    }

    func stop() {
        dayTimer?.invalidate()
        audioListener?.stop()
        observers.forEach(NotificationCenter.default.removeObserver)
        observers = []
    }

    func refresh(force: Bool = false) {
        let latest = DeviceScanner.snapshot()
        usbProducts = USBDevices.productNames()
        micProblem = latest.active(.microphone).flatMap(AudioHardware.micProblem)
        guard force || latest != snapshot else { return }
        snapshot = latest
        remembered = MacAudioMemory.remembered()
        let lastEvent = history.events.last?.id
        recordHistory()
        let start = lastEvent.flatMap { id in history.events.lastIndex { $0.id == id } }.map { $0 + 1 } ?? 0
        onChange?()
        onEvents?(Array(history.events[start...]))
    }

    private func recordHistory() {
        if history.update(snapshot, now: .now) {
            HistoryStore.save(history)
        }
    }

    /// Usually-connected or saved-setup devices that aren't here, with why.
    var missing: [MissingDevice] {
        var seen = Set<String>()
        var result: [MissingDevice] = []
        for (kind, device) in (setup?.devices ?? [:]).sorted(by: { $0.key.rawValue < $1.key.rawValue })
        where !snapshot.contains(device.id, kind: kind) && seen.insert(device.id).inserted {
            result.append(missingDevice(device, lastSeen: history.record(for: device)?.lastSeen))
        }
        for record in history.missingUsual(snapshot, now: .now) where seen.insert(record.device.id).inserted {
            result.append(missingDevice(record.device, lastSeen: record.lastSeen))
        }
        return result
    }

    func missingDevice(_ device: Device, lastSeen: Date?) -> MissingDevice {
        let reason = MissingReason.diagnose(name: device.name, transport: device.transport, usbProducts: usbProducts)
        return MissingDevice(device: device, lastSeen: lastSeen, reason: reason)
    }

    /// Devices macOS has used before that aren't connected now and that Green Room hasn't
    /// recorded itself.
    var rememberedMissing: [MissingDevice] {
        let connected = Set(DeviceKind.allCases.flatMap(snapshot.devices).map(\.name))
        let recorded = Set(history.records.values.map(\.device.name))
        return remembered
            .filter { !connected.contains($0.name) && !recorded.contains($0.name) }
            .map { missingDevice(Device(id: $0.id, name: $0.name, kind: .microphone, transport: .usb), lastSeen: nil) }
    }

    func select(_ device: Device) {
        if device.kind == .camera {
            Cameras.setPreferred(device)
        } else {
            AudioHardware.setDefault(device)
        }
        refresh()
    }

    func saveSetup() {
        setup = Setup.current(snapshot)
        SetupStore.save(setup)
        onChange?()
    }

    func forgetSetup() {
        setup = nil
        SetupStore.save(nil)
        onChange?()
    }

    /// The camera to preview: the one macOS suggests, else the saved one, else any.
    var previewCamera: Device? {
        snapshot.active(.camera)
            ?? setup?.devices[.camera].flatMap { saved in snapshot.devices(.camera).first { $0.id == saved.id } }
            ?? snapshot.devices(.camera).first
    }
}

struct MissingDevice: Identifiable {
    let device: Device
    let lastSeen: Date?
    let reason: MissingReason

    var id: String { "\(device.kind.rawValue):\(device.id)" }
}

enum HistoryStore {
    static var url: URL {
        URL.applicationSupportDirectory.appending(path: "Green Room/history.json")
    }

    static func load() -> DeviceHistory {
        (try? Data(contentsOf: url)).flatMap { try? JSONDecoder().decode(DeviceHistory.self, from: $0) }
            ?? DeviceHistory()
    }

    static func save(_ history: DeviceHistory) {
        guard let data = try? JSONEncoder().encode(history) else { return }
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? data.write(to: url, options: .atomic)
    }
}

enum SetupStore {
    private static let key = "setup"

    static func load() -> Setup? {
        UserDefaults.standard.data(forKey: key).flatMap { try? JSONDecoder().decode(Setup.self, from: $0) }
    }

    static func save(_ setup: Setup?) {
        if let setup, let data = try? JSONEncoder().encode(setup) {
            UserDefaults.standard.set(data, forKey: key)
        } else {
            UserDefaults.standard.removeObject(forKey: key)
        }
    }
}
