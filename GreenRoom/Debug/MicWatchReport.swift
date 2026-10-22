#if DEBUG
import AppKit
import GreenRoomCore

@MainActor
enum MicWatchReport {
    static func testSamples(_ samples: [String: Float]) -> [String: Float] {
        if CommandLine.arguments.contains("--mic-check-simulate-silence") { return samples.mapValues { _ in 0 } }
        return samples
    }

    private static var peaks: [LiveUse: Float] = [:]

    static func write(_ sessions: MicCheckSessions, samples: [String: Float], activeTaps: Int, warning: LiveUse?) {
        let arguments = CommandLine.arguments
        guard let index = arguments.firstIndex(of: "--mic-check-report"), index + 1 < arguments.count else { return }
        peaks = peaks.filter { sessions.checks[$0.key] != nil }
        for use in sessions.checks.keys {
            if let sample = samples[use.deviceID] { peaks[use] = max(peaks[use] ?? 0, sample) }
        }
        let report: [String: Any] = [
            "activeTaps": activeTaps,
            "simulatedSilence": CommandLine.arguments.contains("--mic-check-simulate-silence"),
            "warning": warning?.app ?? "none",
            "frontmost": NSWorkspace.shared.frontmostApplication?.localizedName ?? "none",
            "checks": sessions.checks.map { ["app": $0.key.app ?? "unknown", "device": $0.key.deviceID,
                                              "peak": String(peaks[$0.key] ?? -1),
                                              "result": String(describing: $0.value.result)] },
            "windows": NSApp.windows.filter(\.isVisible).map {
                ["title": $0.title, "frame": NSStringFromRect($0.frame), "key": $0.isKeyWindow.description]
            }
        ]
        guard let data = try? JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted]) else { return }
        try? data.write(to: URL(fileURLWithPath: arguments[index + 1]), options: .atomic)
    }
}
#endif
