import Foundation
import GreenRoomCore
import Observation

/// A live level for every mic at once, so you can see which one hears you before switching.
/// The mics are only open while the comparison is showing.
@MainActor
@Observable
final class InputMeters {
    private(set) var levels: [String: Float] = [:]
    private(set) var isOn = false
    @ObservationIgnored private var taps: [String: InputTap] = [:]
    @ObservationIgnored private var timer: Timer?

    /// Opening a Bluetooth headset's mic drops it into call quality, and the iPhone mic wakes
    /// the phone, so those get tested by switching to them instead.
    static func canMeter(_ device: Device) -> Bool {
        device.transport != .bluetooth && device.transport != .continuity
    }

    func start(_ devices: [Device]) {
        stop()
        isOn = true
        for device in devices where Self.canMeter(device) {
            taps[device.id] = InputTap(device)
        }
        timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 15, repeats: true) { _ in
            MainActor.assumeIsolated { [weak self] in self?.tick() }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        taps.values.forEach { $0.stop() }
        taps = [:]
        levels = [:]
        isOn = false
    }

    private func tick() {
        levels = taps.mapValues { $0.read() }
    }
}
