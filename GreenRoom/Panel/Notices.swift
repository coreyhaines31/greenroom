import GreenRoomCore
import SwiftUI

/// The top of the panel: ready, what's wrong with a button to fix it, or the setup to save.
struct StatusHeader: View {
    let monitor: DeviceMonitor

    var body: some View {
        switch monitor.readiness {
        case .noSetup:
            proposal
        case .ready:
            Label("Ready: \(monitor.setup?.name ?? "your setup")", systemImage: "checkmark.circle.fill")
                .font(.headline).foregroundStyle(.green)
        case .notReady(let issues):
            VStack(alignment: .leading, spacing: 8) {
                Label("Not ready", systemImage: "exclamationmark.triangle.fill")
                    .font(.headline).foregroundStyle(.orange)
                ForEach(issues, id: \.message) { issue in
                    IssueRow(issue: issue, fix: { monitor.select($0) }, ignore: { monitor.ignore(app: $0) })
                }
            }
        }
    }

    /// Before there's a setup, show the guess from history so saving is one click.
    private var proposal: some View {
        // A headset is both mic and speaker; name it once.
        var names: [String] = []
        for kind in DeviceKind.allCases {
            if let name = monitor.proposedSetup.devices[kind]?.name, !names.contains(name) { names.append(name) }
        }
        return VStack(alignment: .leading, spacing: 4) {
            Label("Save your usual devices as your setup", systemImage: "web.camera")
                .font(.headline)
                .fixedSize(horizontal: false, vertical: true)
            if !names.isEmpty {
                Text("You usually use \(ListFormatter.localizedString(byJoining: names)).")
                    .font(.callout).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

struct IssueRow: View {
    let issue: Mismatch
    let fix: (Device) -> Void
    let ignore: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(issue.message).font(.callout)
                .fixedSize(horizontal: false, vertical: true)
            if let advice = issue.advice {
                Text(advice).font(.caption).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            HStack {
                if let device = issue.fix {
                    Button("Switch to \(device.name)") { fix(device) }
                }
                if case .appUsing(let app, _) = issue.problem {
                    Button("Ignore \(app)") { ignore(app) }
                        .help("For apps that always listen, like recorders. Undo in the gear menu.")
                }
            }
            .controlSize(.small)
        }
    }
}

/// A Bluetooth headset in call mode: why it sounds bad, and the better mic to use.
struct AdvisoryCard: View {
    let advisory: Advisory
    let fix: (Device) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(advisory.title, systemImage: "waveform.badge.exclamationmark")
                .font(.callout.weight(.semibold)).foregroundStyle(.orange)
            Text(advisory.message).font(.caption).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            if let device = advisory.fix {
                Button("Use \(device.name)") { fix(device) }
                    .controlSize(.small)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
    }
}

/// Which app has a device of this kind open, so the panel shows what a call really uses.
struct LiveCaption: View {
    let kind: DeviceKind
    let snapshot: Snapshot
    let selected: Device?

    var body: some View {
        ForEach(lines, id: \.self) { line in
            HStack(spacing: 5) {
                Circle().fill(.green).frame(width: 6, height: 6)
                Text(line).font(.caption).foregroundStyle(.secondary)
            }
            .accessibilityElement(children: .combine)
        }
    }

    private var lines: [String] {
        snapshot.devices(kind).filter(snapshot.isLive).map { device in
            let apps = ListFormatter.localizedString(byJoining: snapshot.liveApps(device))
            return device.id == selected?.id ? "Live in \(apps)" : "\(apps) is using \(device.name)"
        }
    }
}
