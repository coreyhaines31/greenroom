import Foundation

/// A short Focus lease is renewed only while a call signal is live. Never issues an off command:
/// macOS expires the lease even if Green Room quits, and a later manual Focus is left alone.
public struct CallHold: Sendable {
    public static let lease: TimeInterval = 120
    public static let renewal: TimeInterval = 45
    public private(set) var expectedFocus = "focus:"
    public private(set) var heldUntil: Date?
    public private(set) var isPaused = false
    private var lastSignal: Date?
    private var lastAttempt: Date?

    public init() {}

    public static func hasDeviceSignal(_ snapshot: Snapshot, ignoring apps: Set<String>) -> Bool {
        snapshot.ignoring(apps: apps).live.contains { $0.kind == .microphone || $0.kind == .camera }
    }

    /// Returns the Focus value the shortcut must match before it changes anything.
    public mutating func request(active: Bool, now: Date) -> String? {
        if active { lastSignal = now }
        if !active, lastSignal.map({ now.timeIntervalSince($0) >= Self.lease }) ?? true {
            self = CallHold()
            return nil
        }
        guard active, !isPaused else { return nil }
        // A missed renewal (sleep, a hung Shortcut) gives up ownership instead of reclaiming Focus.
        if let heldUntil, now >= heldUntil {
            isPaused = true
            return nil
        }
        guard lastAttempt.map({ now.timeIntervalSince($0) >= Self.renewal }) ?? true else { return nil }
        lastAttempt = now
        return expectedFocus
    }

    public mutating func completed(_ result: String, startedAt: Date, now: Date) {
        guard result.hasPrefix("focus:"), result != "focus:", now < startedAt.addingTimeInterval(Self.lease) else {
            isPaused = true
            return
        }
        expectedFocus = result
        // Conservatively date the lease from invocation, not completion.
        heldUntil = startedAt.addingTimeInterval(Self.lease)
    }
}
