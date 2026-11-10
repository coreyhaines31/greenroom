import Foundation

/// Whether you're ready for a call. The one answer the menu bar, the panel, the pre-call alert,
/// `greenroom status` and Shortcuts all share.
public struct ReadyCheck: Sendable, Equatable {
    /// How the devices compare with the setup that fits.
    public let readiness: Readiness
    /// The mic in use is muted in macOS or its input volume is at zero.
    public let micProblem: MicProblem?
    public let advisories: [Advisory]

    public init(readiness: Readiness, micProblem: MicProblem? = nil, advisories: [Advisory] = []) {
        self.readiness = readiness
        self.micProblem = micProblem
        self.advisories = advisories
    }

    /// Silence doesn't count: it takes the level meter to hear it, so only the open panel shows it.
    public static func evaluate(_ snapshot: Snapshot, setup: Setup?, micProblem: MicProblem?) -> ReadyCheck {
        let blocking = micProblem.flatMap { $0 != .silent && snapshot.active(.microphone) != nil ? $0 : nil }
        return ReadyCheck(
            readiness: .evaluate(snapshot, setup: setup), micProblem: blocking,
            advisories: Advisory.evaluate(snapshot)
        )
    }

    public var mismatches: [Mismatch] {
        if case .notReady(let mismatches) = readiness { return mismatches }
        return []
    }

    /// No saved setup still counts as ready when nothing else is wrong.
    public var isReady: Bool { mismatches.isEmpty && micProblem == nil && advisories.isEmpty }
}
