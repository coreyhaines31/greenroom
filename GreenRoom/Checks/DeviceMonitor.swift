import AVFoundation
import GreenRoomCore
import Observation

/// Keeps a live snapshot of connected devices and checks it against the saved setup.
@MainActor
@Observable
final class DeviceMonitor {
    private(set) var snapshot = Snapshot()
    private(set) var setup: Setup? = SetupStore.load()

    var readiness: Readiness { Readiness.evaluate(snapshot, setup: setup) }

    @ObservationIgnored var onChange: (() -> Void)?
    @ObservationIgnored private var audioListener: AudioChangeListener?
    @ObservationIgnored private var observers: [NSObjectProtocol] = []

    func start() {
        let listener = AudioChangeListener { [weak self] in self?.refresh() }
        listener.start()
        audioListener = listener
        for name in [AVCaptureDevice.wasConnectedNotification, AVCaptureDevice.wasDisconnectedNotification] {
            observers.append(NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) { _ in
                MainActor.assumeIsolated { [weak self] in self?.refresh() }
            })
        }
        refresh()
    }

    func stop() {
        audioListener?.stop()
        observers.forEach(NotificationCenter.default.removeObserver)
        observers = []
    }

    func refresh() {
        let latest = DeviceScanner.snapshot()
        guard latest != snapshot else { return }
        snapshot = latest
        onChange?()
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
