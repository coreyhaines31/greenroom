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
    var advisories: [Advisory] { Advisory.evaluate(snapshot) }
    /// What "Save as my setup" saves before there is one: the devices used most, from history.
    var proposedSetup: Setup { Setup.proposed(history: history, snapshot: snapshot, now: .now) }
    var needsAttention: Bool {
        if case .notReady = readiness { return true }
        return !advisories.isEmpty
    }

    @ObservationIgnored var onChange: (() -> Void)?
    /// New timeline events from each device change, for alerts.
    @ObservationIgnored var onEvents: (([DeviceHistory.Event]) -> Void)?
    @ObservationIgnored private var audioListener: AudioChangeListener?
    @ObservationIgnored private var observers: [NSObjectProtocol] = []
    @ObservationIgnored private var dayTimer: Timer?
    @ObservationIgnored private var cameraObservations: [NSKeyValueObservation] = []
    @ObservationIgnored private var pendingRefresh = false

    func start() {
        let listener = AudioChangeListener { [weak self] in self?.scheduleRefresh() }
        listener.start()
        audioListener = listener
        for name in [AVCaptureDevice.wasConnectedNotification, AVCaptureDevice.wasDisconnectedNotification] {
            observers.append(NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) { _ in
                MainActor.assumeIsolated { [weak self] in
                    self?.observeCameras()
                    self?.scheduleRefresh()
                }
            })
        }
        observeCameras()
        // Keeps "seen today" right for devices that stay plugged in for days.
        dayTimer = Timer.scheduledTimer(withTimeInterval: 30 * 60, repeats: true) { _ in
            MainActor.assumeIsolated { [weak self] in self?.recordHistory() }
        }
        refresh(force: true)
    }

    func stop() {
        dayTimer?.invalidate()
        cameraObservations = []
        audioListener?.stop()
        observers.forEach(NotificationCenter.default.removeObserver)
        observers = []
    }

    /// Core Audio sends changes in bursts (a call starting touches several devices), so
    /// they're folded into one refresh.
    func scheduleRefresh() {
        guard !pendingRefresh else { return }
        pendingRefresh = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
            MainActor.assumeIsolated {
                self?.pendingRefresh = false
                self?.refresh()
            }
        }
    }

    /// Cameras say when another app starts or stops using them.
    private func observeCameras() {
        cameraObservations = Cameras.captureDevices().map { camera in
            camera.observe(\.isInUseByAnotherApplication) { _, _ in
                DispatchQueue.main.async { MainActor.assumeIsolated { [weak self] in self?.scheduleRefresh() } }
            }
        }
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

    /// The first save takes the proposal from history; later saves take what's in use now.
    func saveSetup() {
        setup = setup == nil ? proposedSetup : Setup.current(snapshot)
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
    static func load() -> DeviceHistory { Storage.loadHistory() }
    static func save(_ history: DeviceHistory) { Storage.saveHistory(history) }
}

enum SetupStore {
    static func load() -> Setup? { Storage.loadSetup(.standard) }
    static func save(_ setup: Setup?) { Storage.saveSetup(setup, .standard) }
}
