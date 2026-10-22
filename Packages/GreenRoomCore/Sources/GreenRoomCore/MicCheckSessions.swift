import Foundation

/// Each app/device pair gets one check until that app releases the microphone.
public struct MicCheckSessions {
    public private(set) var checks: [LiveUse: MicSignalCheck] = [:]

    public init() {}

    public var pendingDeviceIDs: Set<String> {
        Set(checks.filter { $0.value.result == .listening }.keys.map(\.deviceID))
    }

    public mutating func reconcile(_ snapshot: Snapshot, ignoring apps: Set<String>, now: TimeInterval) {
        let live = Set(snapshot.live.filter { use in
            use.kind == .microphone && use.app.map { !apps.contains($0) } == true
                && snapshot.contains(use.deviceID, kind: .microphone)
        })
        checks = checks.filter { live.contains($0.key) }
        for use in live where checks[use] == nil {
            checks[use] = MicSignalCheck(
                started: now, bluetooth: snapshot.device(use.deviceID, kind: .microphone)?.transport == .bluetooth
            )
        }
    }

    public mutating func observe(_ samples: [String: Float], now: TimeInterval) {
        for use in Array(checks.keys) {
            _ = checks[use]?.observe(level: samples[use.deviceID], now: now)
        }
    }
}
