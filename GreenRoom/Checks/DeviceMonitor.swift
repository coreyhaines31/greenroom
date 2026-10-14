import AVFoundation
import GreenRoomCore
import Observation

/// Keeps a live snapshot of connected devices and checks it against the setup that fits.
@MainActor
@Observable
final class DeviceMonitor {
    private(set) var snapshot = Snapshot()
    private(set) var setups: [Setup] = SetupStore.load()
    private(set) var history = HistoryStore.load()
    private(set) var usbProducts: [String] = []
    private(set) var remembered: [MacAudioMemory.Remembered] = []
    private(set) var micProblem: MicProblem?

    /// Apps whose device use never counts as a problem, like a recorder that's always listening.
    private(set) var ignoredApps = Set(UserDefaults.standard.stringArray(forKey: "ignoredApps") ?? [])

    /// The saved setup that fits what's plugged in right now.
    var setup: Setup? { Setup.bestMatch(setups, snapshot: snapshot) }
    var readiness: Readiness { Readiness.evaluate(snapshot.ignoring(apps: ignoredApps), setup: setup) }
    var advisories: [Advisory] { Advisory.evaluate(snapshot.ignoring(apps: ignoredApps)) }
    /// What "Save as my setup" saves before there is one: the devices used most, from history.
    var proposedSetup: Setup { Setup.proposed(history: history, snapshot: snapshot, now: .now) }
    var flaky: [FlakyDevice] { FlakyDevice.find(in: history, now: .now) }
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
    @ObservationIgnored private var lastSave = Date.distantPast

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
        audioListener = nil
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
        let onChange = Self.cameraChangeHandler { [weak self] in self?.scheduleRefresh() }
        cameraObservations = Cameras.captureDevices().map { camera in
            camera.observe(\.isInUseByAnotherApplication) { _, _ in onChange() }
        }
    }

    /// KVO calls back on AVFoundation's threads, so the handler is made outside the main actor
    /// and hops back to it.
    nonisolated static func cameraChangeHandler(
        _ refresh: @escaping @MainActor @Sendable () -> Void
    ) -> @Sendable () -> Void {
        { DispatchQueue.main.async { MainActor.assumeIsolated { refresh() } } }
    }

    func refresh(force: Bool = false) {
        let latest = DeviceScanner.snapshot()
        // Apps start and stop sounds all day; only a real change pays for the slower checks.
        guard force || latest != snapshot else { return }
        usbProducts = USBDevices.productNames()
        micProblem = latest.active(.microphone).flatMap(AudioHardware.micProblem)
        snapshot = latest
        remembered = MacAudioMemory.remembered()
        let lastEvent = history.events.last?.id
        recordHistory()
        let start = lastEvent.flatMap { id in history.events.lastIndex { $0.id == id } }.map { $0 + 1 } ?? 0
        onChange?()
        onEvents?(Array(history.events[start...]))
    }

    /// Saves when something real changed (a device, an event, a new day), and otherwise at most
    /// every few minutes: apps start and stop sound all day, and each one refreshes.
    private func recordHistory() {
        let before = history
        guard history.update(snapshot, now: .now) else { return }
        let activeDays = { (history: DeviceHistory) in history.records.values.map { $0.activeDays?.count ?? 0 } }
        let changed = history.events != before.events || history.records.count != before.records.count
            || history.appDays != before.appDays || activeDays(history) != activeDays(before)
        if changed || Date.now.timeIntervalSince(lastSave) > 5 * 60 {
            HistoryStore.save(history)
            lastSave = .now
        }
    }

    func ignore(app: String) {
        ignoredApps.insert(app)
        UserDefaults.standard.set(ignoredApps.sorted(), forKey: "ignoredApps")
        onChange?()
    }

    func stopIgnoring(app: String) {
        ignoredApps.remove(app)
        UserDefaults.standard.set(ignoredApps.sorted(), forKey: "ignoredApps")
        onChange?()
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

    /// Devices you picked in Green Room, and when. Keep my setup never reverts these.
    @ObservationIgnored private(set) var chosenByYou: [String: Date] = [:]

    func chosenRecently(within seconds: TimeInterval) -> Set<String> {
        Set(chosenByYou.filter { Date.now.timeIntervalSince($0.value) <= seconds }.keys)
    }

    /// Switching back for Keep my setup isn't a choice of yours, so it skips the bookkeeping.
    func select(_ device: Device, byYou: Bool = true) {
        if byYou { chosenByYou[device.id] = .now }
        if device.kind == .camera {
            Cameras.setPreferred(device)
        } else {
            AudioHardware.setDefault(device)
        }
        refresh()
    }

    /// The first save takes the proposal from history. After that it updates the setup that
    /// fits to what's in use now.
    func saveSetup() {
        guard let current = setup else {
            store([withDate(proposedSetup)])
            return
        }
        saveNewSetup(named: current.name)
    }

    /// Saves what's in use now under a name, replacing a setup with that name.
    func saveNewSetup(named name: String) {
        let setup = withDate(Setup.current(snapshot, name: name))
        store(setups.filter { $0.name != name } + [setup])
    }

    func forget(_ setup: Setup) {
        store(setups.filter { $0.name != setup.name })
    }

    /// Makes the setup's connected mic, speaker, and camera the ones in use.
    func apply(_ setup: Setup) {
        for device in setup.devices.values {
            if let connected = snapshot.device(device.id, kind: device.kind) {
                chosenByYou[connected.id] = .now
                if device.kind == .camera {
                    Cameras.setPreferred(connected)
                } else {
                    AudioHardware.setDefault(connected)
                }
            }
        }
        store(setups.map { $0.name == setup.name ? withDate($0) : $0 })
        refresh(force: true)
    }

    private func withDate(_ setup: Setup) -> Setup {
        var setup = setup
        setup.lastUsed = .now
        return setup
    }

    private func store(_ setups: [Setup]) {
        self.setups = setups
        SetupStore.save(setups)
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
    static func load() -> [Setup] { Storage.loadSetups(.standard) }
    static func save(_ setups: [Setup]) { Storage.saveSetups(setups, .standard) }
}
