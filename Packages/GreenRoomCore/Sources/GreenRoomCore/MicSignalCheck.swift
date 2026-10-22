import Foundation

/// A bounded startup check, not a speech detector or a continuous recording monitor.
public struct MicSignalCheck: Sendable {
    public enum Result: Sendable, Equatable {
        case listening, soundDetected, silent, unavailable
    }

    public private(set) var result: Result = .listening
    private let started: TimeInterval
    private let duration: TimeInterval
    private var receivedAudio = false

    public init(started: TimeInterval, bluetooth: Bool = false) {
        self.started = started
        duration = bluetooth ? 10 : 4
    }

    public mutating func observe(level: Float?, now: TimeInterval) -> Result {
        guard result == .listening else { return result }
        if let level, level.isFinite {
            receivedAudio = true
            if level > 0.1 { result = .soundDetected }
        }
        if result == .listening, now - started >= duration {
            result = receivedAudio ? .silent : .unavailable
        }
        return result
    }
}
