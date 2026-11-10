import Foundation

/// What's connected and the saved setups, under the names you gave the devices, plus the setup
/// that fits. The `greenroom` command and the Shortcuts actions both start here, so they agree.
public struct CurrentDevices: Sendable {
    public let snapshot: Snapshot
    public let setups: [Setup]
    public let setup: Setup?

    public init(scanned: Snapshot, setups: [Setup], names: DeviceNames, ignoredApps: Set<String>) {
        snapshot = names.apply(scanned).ignoring(apps: ignoredApps)
        self.setups = setups.map(names.apply)
        setup = Setup.bestMatch(self.setups, snapshot: snapshot)
    }

    public func report(
        history: DeviceHistory, usbProducts: [String], now: Date,
        micProblem: (Device) -> MicProblem? = AudioHardware.micProblem
    ) -> StatusReport {
        StatusReport.make(
            snapshot: snapshot, setup: setup, history: history, usbProducts: usbProducts,
            micProblem: snapshot.active(.microphone).flatMap(micProblem), now: now
        )
    }
}
