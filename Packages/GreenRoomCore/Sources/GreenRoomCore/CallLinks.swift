import Foundation

/// Spots calendar events that are video calls, from the meeting link in their location,
/// notes, or URL.
public enum CallLinks {
    static let hosts = [
        "zoom.us", "meet.google.com", "teams.microsoft.com", "teams.live.com", "webex.com",
        "whereby.com", "around.co", "riverside.fm", "streamyard.com", "facetime.apple.com",
        "gather.town", "chime.aws", "bluejeans.com", "gotomeeting.com", "meet.goto.com",
        "app.slack.com/huddle", "discord.com", "tuple.app", "pop.com", "cal.com/video"
    ]

    public static func isVideoCall(_ texts: [String?]) -> Bool {
        let haystack = texts.compactMap { $0?.lowercased() }.joined(separator: " ")
        return hosts.contains { haystack.contains($0) }
    }

    /// The readiness problems worth a heads-up before a call, most important first.
    public static func preCallProblems(readiness: Readiness) -> [Mismatch] {
        guard case .notReady(let mismatches) = readiness else { return [] }
        // An app using the wrong device only matters once the call has started.
        return mismatches.filter {
            if case .appUsing = $0.problem { return false }
            return true
        }
    }
}
