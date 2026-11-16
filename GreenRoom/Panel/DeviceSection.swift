import GreenRoomCore
import PanelKit
import SwiftUI

/// A section for one kind of device: header, the device menu, live captions and the row's button.
struct DeviceSection<HeaderAction: View, Detail: View, Trailing: View>: View {
    let kind: DeviceKind
    let monitor: DeviceMonitor
    let selected: Device?
    @ViewBuilder var headerAction: HeaderAction
    /// Under the device's name, like the mic's level.
    @ViewBuilder var detail: Detail
    /// On the right of the row, like the speaker's Test button.
    @ViewBuilder var trailing: Trailing

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionHeader(kind.title)
                .trailingAccessory { headerAction }
            HStack(alignment: .center, spacing: 10) {
                SymbolTile(kind.panelSymbol, bare: true)
                VStack(alignment: .leading, spacing: 4) {
                    DeviceChooser(kind: kind, monitor: monitor, selected: selected)
                    detail
                    let snapshot = monitor.snapshot.ignoring(apps: monitor.ignoredApps)
                    LiveCaption(kind: kind, snapshot: snapshot, selected: selected) {
                        monitor.ignore(app: $0)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                trailing
            }
            .padding(.vertical, 7)
            .padding(.horizontal, 14)
        }
    }
}

extension DeviceSection where HeaderAction == EmptyView, Detail == EmptyView, Trailing == EmptyView {
    init(kind: DeviceKind, monitor: DeviceMonitor, selected: Device?) {
        self.init(kind: kind, monitor: monitor, selected: selected) {
            EmptyView()
        } detail: {
            EmptyView()
        } trailing: {
            EmptyView()
        }
    }
}

extension DeviceKind {
    var panelSymbol: String {
        switch self {
        case .camera: "video"
        case .microphone: "mic"
        case .speaker: "speaker.wave.2"
        }
    }
}

/// The device's name as a menu of every device of its kind. Picking one makes it the Mac's default.
struct DeviceChooser: View {
    let kind: DeviceKind
    let monitor: DeviceMonitor
    let selected: Device?
    @Environment(\.panelTheme) private var theme

    var body: some View {
        // A hidden device still shows while it's the one in use.
        let devices = monitor.snapshot.devices(kind).filter { !monitor.names.isHidden($0) || $0.id == selected?.id }
        Menu {
            Picker(kind.title, selection: Binding(
                get: { selected?.id ?? "" },
                set: { id in devices.first { $0.id == id }.map { monitor.select($0) } }
            )) {
                if selected == nil { Text("None").tag("") }
                ForEach(devices) { device in
                    Text("\(device.name) · \(device.transport.label)").tag(device.id)
                }
            }
            .pickerStyle(.inline)
            .labelsHidden()
        } label: {
            HStack(spacing: 5) {
                Text(selected.map { "\($0.name) · \($0.transport.label)" } ?? "None")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(theme.ink)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(theme.sub)
            }
            .contentShape(Rectangle())
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .menuIndicator(.hidden)
        .fixedSize(horizontal: false, vertical: true)
        .help("Choose the \(kind.title.lowercased()). It becomes your Mac's default.")
        .accessibilityLabel(kind.title)
        .accessibilityValue(selected?.name ?? "None")
    }
}

/// The menu of devices of one kind, as a pop-up button. Used by the record preview.
struct DeviceMenu: View {
    let kind: DeviceKind
    let monitor: DeviceMonitor
    let selected: Device?
    /// "USB", "Built-in": useful in the panel, noise on a full-screen preview.
    var showsTransport = true

    var body: some View {
        // A hidden device still shows while it's the one in use.
        let devices = monitor.snapshot.devices(kind).filter { !monitor.names.isHidden($0) || $0.id == selected?.id }
        Picker(kind.title, selection: Binding(
            get: { selected?.id ?? "" },
            set: { id in devices.first { $0.id == id }.map { monitor.select($0) } }
        )) {
            if selected == nil { Text("None").tag("") }
            ForEach(devices) { device in
                Text(showsTransport ? "\(device.name) · \(device.transport.label)" : device.name).tag(device.id)
            }
        }
        .labelsHidden()
    }
}

/// Every mic with its own live level. Click one to use it.
struct MicComparison: View {
    let mics: [Device]
    let active: Device?
    let levels: [String: Float]
    let select: (Device) -> Void
    @Environment(\.panelTheme) private var theme

    var body: some View {
        VStack(spacing: 0) {
            ForEach(mics) { device in
                Button { select(device) } label: { row(device) }
                    .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(theme.field, in: RoundedRectangle(cornerRadius: 6))
        .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(theme.line, lineWidth: 1))
    }

    private func row(_ device: Device) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(theme.ink)
                .opacity(device.id == active?.id ? 1 : 0)
            Text(device.name)
                .font(.system(size: 12.5, weight: device.id == active?.id ? .semibold : .regular))
                .foregroundStyle(theme.ink)
                .lineLimit(1)
                .truncationMode(.tail)
            Spacer(minLength: 8)
            if InputMeters.canMeter(device) {
                LevelMeter(level: Double(levels[device.id] ?? 0), stopFrom: 7)
                    .accessibilityLabel("\(device.name) level")
            } else if device.id != active?.id {
                Text("Switch to test").font(.system(size: 11)).foregroundStyle(theme.sub)
                    .help(device.transport == .bluetooth
                        ? "Opening a headset's mic drops it to call quality, so it's only tested once you use it."
                        : "Opening the iPhone mic wakes your phone, so it's only tested once you use it.")
            }
        }
        .padding(.vertical, 5)
        .contentShape(Rectangle())
        .accessibilityAddTraits(device.id == active?.id ? .isSelected : [])
    }
}
