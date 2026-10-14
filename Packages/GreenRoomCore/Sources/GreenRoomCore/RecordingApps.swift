import Foundation

/// Apps that record, as opposed to call. When one of them turns on your mic, it's time for
/// "Ready to record?", not the call checks.
public enum RecordingApps {
    static let names: Set<String> = [
        "loom", "obs", "screen studio", "quicktime player", "screenflow", "riverside", "descript",
        "camtasia", "cleanshot x", "kap", "ecamm live", "logic pro", "garageband", "audacity",
        "final cut pro", "adobe premiere pro", "adobe audition", "rode central", "streamlabs",
        "mmhmm", "cap", "tella", "screenpal", "vidyard", "detail", "rewind"
    ]

    public static func isRecorder(_ app: String) -> Bool {
        names.contains(app.lowercased())
    }

    /// Recording apps that started using a mic since the last snapshot.
    public static func started(before: Snapshot, after: Snapshot) -> Set<String> {
        func recorders(_ snapshot: Snapshot) -> Set<String> {
            Set(snapshot.live.filter { $0.kind == .microphone }.compactMap(\.app).filter(isRecorder))
        }
        return recorders(after).subtracting(recorders(before))
    }
}
