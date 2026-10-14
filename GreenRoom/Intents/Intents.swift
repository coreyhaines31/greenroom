import AppIntents
import GreenRoomCore

/// A saved setup, for Shortcuts. Identified by name, since names are unique.
struct SetupEntity: AppEntity {
    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Setup"
    static let defaultQuery = SetupQuery()

    let id: String

    var displayRepresentation: DisplayRepresentation { DisplayRepresentation(title: "\(id)") }
}

struct SetupQuery: EntityQuery {
    func entities(for identifiers: [String]) async throws -> [SetupEntity] {
        let names = Set(Storage.loadSetups(.standard).map(\.name))
        return identifiers.filter(names.contains).map(SetupEntity.init(id:))
    }

    func suggestedEntities() async throws -> [SetupEntity] {
        Storage.loadSetups(.standard).map { SetupEntity(id: $0.name) }
    }
}

/// "Use Studio setup": makes the setup's mic and speaker the Mac's defaults.
struct UseSetupIntent: AppIntent {
    static let title: LocalizedStringResource = "Use Setup"
    static let description = IntentDescription("Switches your Mac's microphone and speaker to a saved setup's devices.")

    @Parameter(title: "Setup")
    var setup: SetupEntity

    static var parameterSummary: some ParameterSummary { Summary("Use \(\.$setup) setup") }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard let chosen = Storage.loadSetups(.standard).first(where: { $0.name == setup.id }) else {
            return .result(dialog: "There's no setup named \(setup.id) anymore.")
        }
        let snapshot = DeviceScanner.snapshot()
        var missing: [String] = []
        for kind in [DeviceKind.microphone, .speaker] {
            guard let device = chosen.devices[kind] else { continue }
            if let connected = snapshot.device(device.id, kind: kind) {
                AudioHardware.setDefault(connected)
            } else {
                missing.append(device.name)
            }
        }
        if missing.isEmpty { return .result(dialog: "Using \(chosen.name).") }
        let list = ListFormatter.localizedString(byJoining: missing)
        return .result(dialog: "Using \(chosen.name), but \(list) isn't connected.")
    }
}

/// "Check my setup": says whether you're ready, and returns true or false for automations.
struct CheckSetupIntent: AppIntent {
    static let title: LocalizedStringResource = "Check My Setup"
    static let description = IntentDescription(
        "Checks your camera, microphone, and speaker against your setup, and says what to fix."
    )

    func perform() async throws -> some IntentResult & ReturnsValue<Bool> & ProvidesDialog {
        let snapshot = DeviceScanner.snapshot()
        let defaults = UserDefaults.standard
        let ignored = Set(defaults.stringArray(forKey: "ignoredApps") ?? [])
        let report = StatusReport.make(
            snapshot: snapshot.ignoring(apps: ignored),
            setup: Setup.bestMatch(Storage.loadSetups(defaults), snapshot: snapshot),
            history: Storage.loadHistory(), usbProducts: USBDevices.productNames(),
            micProblem: snapshot.active(.microphone).flatMap(AudioHardware.micProblem), now: .now
        )
        if report.ready {
            return .result(value: true, dialog: "You're ready\(report.setup.map { ": \($0) matches" } ?? "").")
        }
        let first = report.problems.first.map { "\($0.message). \($0.advice)" } ?? "Something needs a look."
        return .result(value: false, dialog: "Not ready. \(first)")
    }
}

struct GreenRoomShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: CheckSetupIntent(),
            phrases: ["Check my setup in \(.applicationName)", "Am I ready in \(.applicationName)"],
            shortTitle: "Check My Setup", systemImageName: "web.camera"
        )
        AppShortcut(
            intent: UseSetupIntent(),
            phrases: ["Use \(\.$setup) in \(.applicationName)", "Switch to \(\.$setup) in \(.applicationName)"],
            shortTitle: "Use Setup", systemImageName: "slider.horizontal.3"
        )
    }
}
