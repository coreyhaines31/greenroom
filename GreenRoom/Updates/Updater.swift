import Sparkle

/// Sparkle auto-updates, fed from the appcast attached to each GitHub release.
@MainActor
final class Updater {
    private let controller = SPUStandardUpdaterController(
        startingUpdater: true,
        updaterDelegate: nil,
        userDriverDelegate: nil
    )

    var canCheck: Bool { controller.updater.canCheckForUpdates }

    var checksAutomatically: Bool {
        get { controller.updater.automaticallyChecksForUpdates }
        set { controller.updater.automaticallyChecksForUpdates = newValue }
    }

    func checkForUpdates() {
        controller.checkForUpdates(nil)
    }
}
