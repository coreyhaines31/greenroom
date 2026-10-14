import Foundation

/// Everything `greenroom status` reports: what's in use, and anything that needs fixing.
public struct StatusReport: Codable, Sendable, Equatable {
    public struct InUse: Codable, Sendable, Equatable {
        public let kind: DeviceKind
        public let name: String
        public let transport: Transport
        /// Apps using it right now.
        public let liveIn: [String]
    }

    public struct Problem: Codable, Sendable, Equatable {
        public let kind: DeviceKind
        public let device: String
        public let message: String
        public let advice: String
        public let lastSeen: Date?
    }

    public let ready: Bool
    public let setup: String?
    public let inUse: [InUse]
    public let problems: [Problem]
    /// Devices that keep disconnecting. Worth fixing, but they don't make you not ready.
    public let flaky: [String]
    /// Usual wired devices that aren't connected. Only a setup's devices make you not ready.
    public let missing: [String]

    // swiftlint:disable:next function_parameter_count
    public static func make(
        snapshot: Snapshot, setup: Setup?, history: DeviceHistory, usbProducts: [String],
        micProblem: MicProblem?, now: Date
    ) -> StatusReport {
        func advice(_ device: Device) -> MissingReason {
            .diagnose(name: device.name, transport: device.transport, usbProducts: usbProducts)
        }
        var problems: [Problem] = []
        var named = Set<String>()
        if case .notReady(let mismatches) = Readiness.evaluate(snapshot, setup: setup) {
            for mismatch in mismatches {
                named.insert(mismatch.expected.id)
                let text = mismatch.problem == .missing
                    ? advice(mismatch.expected).advice
                    : mismatch.advice ?? "Switch back in Green Room, or System Settings › Sound."
                problems.append(Problem(
                    kind: mismatch.kind, device: mismatch.expected.name, message: mismatch.message, advice: text,
                    lastSeen: history.record(for: mismatch.expected)?.lastSeen
                ))
            }
        }
        if let micProblem, let mic = snapshot.active(.microphone), micProblem != .silent {
            problems.append(Problem(
                kind: .microphone, device: mic.name, message: micProblem.message, advice: micProblem.message,
                lastSeen: nil
            ))
        }
        let missing = history.missingUsual(snapshot, now: now)
            .filter { named.insert($0.device.id).inserted }
            .map { record -> String in
                let reason = advice(record.device)
                return "\(record.device.name): \(reason.headline.lowercased()). \(reason.advice)"
            }
        for advisory in Advisory.evaluate(snapshot) {
            problems.append(Problem(
                kind: .microphone, device: advisory.device.name, message: advisory.title, advice: advisory.message,
                lastSeen: nil
            ))
        }
        let inUse = DeviceKind.allCases.compactMap { kind in
            snapshot.active(kind).map {
                InUse(kind: kind, name: $0.name, transport: $0.transport, liveIn: snapshot.liveApps($0))
            }
        }
        let flaky = FlakyDevice.find(in: history, now: now).map { "\($0.message). \($0.advice)" }
        return StatusReport(
            ready: problems.isEmpty, setup: setup?.name, inUse: inUse, problems: problems, flaky: flaky,
            missing: missing
        )
    }

    public var text: String {
        var lines: [String] = []
        if problems.isEmpty {
            lines.append(setup.map { "Ready: \($0) matches." } ?? "No problems found. No setup saved yet.")
        } else {
            lines.append("Not ready: \(problems.count) to fix.")
        }
        lines.append("")
        for kind in DeviceKind.allCases {
            let device = inUse.first { $0.kind == kind }
            let label = kind == .camera ? "Camera (suggested)" : kind.title
            lines.append("\(label.padding(toLength: 19, withPad: " ", startingAt: 0))"
                + (device.map { "\($0.name) · \($0.transport.label)" + live($0.liveIn) }
                    ?? (kind == .camera ? "none set, so each app picks its own" : "none")))
        }
        if !problems.isEmpty {
            lines.append("")
            for problem in problems {
                lines.append("! \(problem.message)")
                if problem.advice != problem.message { lines.append("  \(problem.advice)") }
            }
        }
        if !missing.isEmpty || !flaky.isEmpty {
            lines.append("")
            lines += missing.map { "~ \($0)" } + flaky.map { "~ \($0)" }
        }
        return lines.joined(separator: "\n")
    }

    private func live(_ apps: [String]) -> String {
        apps.isEmpty ? "" : " · live in \(ListFormatter.localizedString(byJoining: apps))"
    }
}
