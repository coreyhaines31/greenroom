import GreenRoomCore
import PanelKit
import SwiftUI

/// Under the fascia: ready, what's wrong with buttons to fix it, or the setup to save.
struct StatusVerdict: View {
    let check: ReadyCheck
    let setupName: String?
    /// The setup guessed from history, offered before there's one.
    let proposed: Setup
    let select: (Device) -> Void
    let ignore: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if !check.isReady {
                problems(check)
            }
            if check.readiness == .noSetup {
                proposal(asVerdict: check.isReady)
            } else if check.isReady {
                let name = setupName ?? "your setup"
                Verdict("Ready: \(name)", message: "Everything matches your \(name) setup.",
                        status: .go, statusLabel: "Ready")
            }
        }
    }

    @ViewBuilder
    private func problems(_ check: ReadyCheck) -> some View {
        let first = check.mismatches.first
        // Call-mode advisories have their own cards just below.
        let title = first?.message ?? check.micProblem?.message ?? callModeTitle(check)
        Verdict(title, message: first.flatMap { message(for: $0, check: check) },
                status: .caution, statusLabel: "Not ready")
        if let first {
            IssueActions(issue: first, fix: select, ignore: ignore)
        }
        ForEach(check.mismatches.dropFirst(), id: \.message) { issue in
            IssueRow(issue: issue, fix: select, ignore: ignore)
        }
        if first != nil, let micProblem = check.micProblem {
            PanelNote(text: micProblem.message, caution: true)
        }
    }

    private func callModeTitle(_ check: ReadyCheck) -> String {
        let count = check.advisories.count
        return count == 1 ? "A headset is in call mode" : "\(count) headsets are in call mode"
    }

    /// The issue's advice, or, when it's the only thing wrong, that the rest is fine.
    private func message(for issue: Mismatch, check: ReadyCheck) -> String? {
        if let advice = issue.advice { return advice }
        let onlyIssue = check.mismatches.count == 1 && check.micProblem == nil && check.advisories.isEmpty
        guard onlyIssue, let name = setupName else { return nil }
        return "Everything else matches your \(name) setup."
    }

    /// Before there's a setup, show the guess from history so saving is one click.
    @ViewBuilder
    private func proposal(asVerdict: Bool) -> some View {
        // A headset is both mic and speaker; name it once.
        let names = DeviceKind.allCases.reduce(into: [String]()) { names, kind in
            if let name = proposed.devices[kind]?.name, !names.contains(name) { names.append(name) }
        }
        let usual = names.isEmpty ? nil : "You usually use \(ListFormatter.localizedString(byJoining: names))."
        if asVerdict {
            Verdict("Save your usual devices as your setup", message: usual, status: .off, statusLabel: "No setup")
        } else {
            Notice("Save your usual devices as your setup", message: usual)
        }
    }
}

/// The first issue's fixes, as the verdict's buttons.
struct IssueActions: View {
    let issue: Mismatch
    let fix: (Device) -> Void
    let ignore: (String) -> Void

    var body: some View {
        let ignoreAction = ignoredApp.map { app in PanelAction("Ignore \(app)") { ignore(app) } }
        if let device = issue.fix {
            ActionBar(primary: PanelAction("Switch to \(device.name)") { fix(device) }, secondary: ignoreAction)
                .help(ignoredApp == nil ? "" : "For apps that always listen, like recorders. Undo in Settings.")
        } else if let ignoreAction {
            ActionBar(primary: ignoreAction)
                .help("For apps that always listen, like recorders. Undo in Settings.")
        }
    }

    private var ignoredApp: String? {
        if case .appUsing(let app, _) = issue.problem { return app }
        return nil
    }
}

/// A second or later issue: what's wrong, advice, and the same buttons, smaller.
struct IssueRow: View {
    let issue: Mismatch
    let fix: (Device) -> Void
    let ignore: (String) -> Void
    @Environment(\.panelTheme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Circle().fill(theme.caution).frame(width: 6, height: 6).accessibilityHidden(true)
                Text(issue.message)
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(theme.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let advice = issue.advice {
                Text(advice)
                    .font(.system(size: 11.5))
                    .foregroundStyle(theme.sub)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.leading, 12)
            }
            HStack(spacing: 6) {
                if let device = issue.fix {
                    Button("Switch to \(device.name)") { fix(device) }
                }
                if case .appUsing(let app, _) = issue.problem {
                    Button("Ignore \(app)") { ignore(app) }
                        .help("For apps that always listen, like recorders. Undo in Settings.")
                }
            }
            .buttonStyle(.panelCompact)
            .padding(.leading, 12)
            .padding(.top, 2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 14)
        .padding(.bottom, 10)
    }
}

/// A Bluetooth headset in call mode: why it sounds bad, and the better mic to use.
struct AdvisoryCard: View {
    let advisory: Advisory
    let fix: (Device) -> Void

    var body: some View {
        Notice(advisory.title, message: advisory.message) {
            if let device = advisory.fix {
                Button("Use \(device.name)") { fix(device) }
                    .buttonStyle(.panelCompact)
            }
        }
    }
}

/// Which app has a device of this kind open, so the panel shows what a call really uses.
struct LiveCaption: View {
    let kind: DeviceKind
    let snapshot: Snapshot
    let selected: Device?
    /// For an app that always listens, like a screen recorder, so it stops crowding out the call.
    let ignore: (String) -> Void
    @Environment(\.panelTheme) private var theme

    var body: some View {
        ForEach(snapshot.devices(kind).filter(snapshot.isLive)) { device in
            HStack(spacing: 5) {
                Circle().fill(theme.go).frame(width: 6, height: 6).accessibilityHidden(true)
                Text(text(device)).foregroundStyle(theme.sub)
                ignoreButton(named(device))
            }
            .font(.system(size: 11.5))
        }
    }

    private func text(_ device: Device) -> String {
        let apps = ListFormatter.localizedString(byJoining: snapshot.liveApps(device))
        return device.id == selected?.id ? "Live in \(apps)" : "\(apps) is using \(device.name)"
    }

    /// Only apps macOS could name can be ignored.
    private func named(_ device: Device) -> [String] {
        snapshot.live.filter { $0.kind == device.kind && $0.deviceID == device.id }.compactMap(\.app)
    }

    @ViewBuilder
    private func ignoreButton(_ apps: [String]) -> some View {
        if apps.count == 1, let app = apps.first {
            Button("Ignore") { ignore(app) }
                .buttonStyle(.panelQuietLink)
                .help("Stop showing \(app) here and in warnings. Undo in Settings.")
        } else if apps.count > 1 {
            Menu {
                ForEach(apps, id: \.self) { app in
                    Button(app) { ignore(app) }
                }
            } label: {
                Text("Ignore").font(.system(size: 11.5))
            }
            .menuStyle(.button)
            .buttonStyle(.panelQuietLink)
            .menuIndicator(.hidden)
            .fixedSize()
            .help("Stop showing an app here and in warnings. Undo in Settings.")
        }
    }
}
