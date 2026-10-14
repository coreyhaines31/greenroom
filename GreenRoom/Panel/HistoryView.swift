import GreenRoomCore
import SwiftUI

struct HistoryView: View {
    let monitor: DeviceMonitor
    @State private var tab = Tab.devices

    enum Tab { case devices, timeline }

    var body: some View {
        VStack(spacing: 0) {
            Picker("Show", selection: $tab) {
                Text("Devices").tag(Tab.devices)
                Text("Timeline").tag(Tab.timeline)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .fixedSize()
            .padding(12)
            Divider()
            switch tab {
            case .devices: devices
            case .timeline: timeline
            }
        }
        .frame(minWidth: 420, minHeight: 360)
    }

    private var devices: some View {
        List {
            ForEach(DeviceKind.allCases, id: \.self) { kind in
                Section(kind.title) {
                    ForEach(connected(kind)) { device in
                        ConnectedRow(device: device, inUse: monitor.snapshot.active(kind)?.id == device.id)
                    }
                    ForEach(notConnected(kind)) { missing in
                        HistoryMissingRow(missing: missing)
                    }
                }
            }
            if !monitor.rememberedMissing.isEmpty {
                Section("Used on this Mac before") {
                    ForEach(monitor.rememberedMissing) { missing in
                        HistoryMissingRow(missing: missing)
                    }
                }
            }
        }
    }

    private func connected(_ kind: DeviceKind) -> [Device] {
        monitor.snapshot.devices(kind)
    }

    private func notConnected(_ kind: DeviceKind) -> [MissingDevice] {
        monitor.history.records.values
            .filter { $0.device.kind == kind && !monitor.snapshot.contains($0.device.id, kind: kind) }
            .sorted { $0.lastSeen > $1.lastSeen }
            .map { monitor.missingDevice($0.device, lastSeen: $0.lastSeen) }
    }

    @ViewBuilder
    private var timeline: some View {
        let events = monitor.history.events.reversed()
        if events.isEmpty {
            ContentUnavailableView(
                "Nothing yet",
                systemImage: "clock",
                description: Text("Plugging in, unplugging, and switching devices will show up here.")
            )
        } else {
            List(Array(events)) { event in
                EventRow(event: event)
            }
        }
    }
}

struct ConnectedRow: View {
    let device: Device
    let inUse: Bool

    var body: some View {
        HStack {
            Circle().fill(.green).frame(width: 8, height: 8)
            Text(device.name)
            Text(device.transport.label).foregroundStyle(.secondary)
            Spacer()
            Text(inUse ? "In use" : "Connected").font(.caption).foregroundStyle(.secondary)
        }
    }
}

struct HistoryMissingRow: View {
    let missing: MissingDevice

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Circle().fill(.secondary.opacity(0.4)).frame(width: 8, height: 8)
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(missing.device.name)
                    Text(missing.device.transport.label).foregroundStyle(.secondary)
                }
                Text(missing.reason.advice).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(missing.reason.headline).font(.caption).foregroundStyle(.orange)
                if let lastSeen = missing.lastSeen {
                    Text("Last seen \(LastSeen.text(lastSeen))").font(.caption).foregroundStyle(.secondary)
                }
            }
        }
    }
}

struct EventRow: View {
    let event: DeviceHistory.Event

    var body: some View {
        HStack {
            Image(systemName: symbol).foregroundStyle(color).frame(width: 16)
            Text(text)
            Spacer()
            Text(event.time.formatted(date: .abbreviated, time: .shortened))
                .font(.caption).foregroundStyle(.secondary).monospacedDigit()
        }
    }

    private var text: String {
        switch event.change {
        case .connected: "\(event.device.name) connected"
        case .disconnected: "\(event.device.name) disconnected"
        case .selected:
            event.device.kind == .speaker
                ? "Sound switched to \(event.device.name)"
                : "\(event.device.kind.title) switched to \(event.device.name)"
        }
    }

    private var symbol: String {
        switch event.change {
        case .connected: "plus.circle.fill"
        case .disconnected: "minus.circle.fill"
        case .selected: "arrow.left.arrow.right.circle.fill"
        }
    }

    private var color: Color {
        switch event.change {
        case .connected: .green
        case .disconnected: .orange
        case .selected: .blue
        }
    }
}
