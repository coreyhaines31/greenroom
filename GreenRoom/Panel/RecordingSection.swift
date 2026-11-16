import GreenRoomCore
import PanelKit
import SwiftUI

/// "Ready to record?": camera format, mic quality, disk space, and power. Collapsed until you
/// open it, since it only matters before a recording.
struct RecordingSection: View {
    let monitor: DeviceMonitor
    @AppStorage("showRecordingCheck") private var expanded = false

    var body: some View {
        // Reads the disk, power, and camera once per render.
        let check = monitor.recordingCheck
        let problems = check.items.filter { !$0.passed }.count
        Disclosure("Ready to record?", isExpanded: $expanded) {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(check.items, id: \.title) { item in
                    RecordingCheckRow(item: item)
                }
            }
            .padding(.bottom, 6)
        }
        .overlay(alignment: .topTrailing) {
            StatusLight(problems == 0 ? .go : .caution, problems == 0 ? "Yes" : "\(problems) to check")
                .padding(.top, 13)
                .padding(.trailing, 14)
                .allowsHitTesting(false)
        }
        .overlay(alignment: .top) {
            PanelHairline()
        }
    }
}

/// One item of the recording check in the panel, with its status light.
struct RecordingCheckRow: View {
    let item: RecordingCheck.Item
    @Environment(\.panelTheme) private var theme

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(theme.ink)
                Text(item.detail)
                    .font(.system(size: 11.5))
                    .foregroundStyle(theme.sub)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            StatusLight(item.passed ? .go : .caution, item.passed ? "OK" : "Check")
        }
        .padding(.leading, 46)
        .padding(.trailing, 14)
        .padding(.vertical, 5)
        .accessibilityElement(children: .combine)
    }
}

/// Each item of the recording check, passed or not.
struct RecordingChecklist: View {
    let check: RecordingCheck

    var body: some View {
        ForEach(check.items, id: \.title) { item in
            Label {
                VStack(alignment: .leading, spacing: 1) {
                    Text(item.title).font(.callout)
                    Text(item.detail).font(.caption).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            } icon: {
                Image(systemName: item.passed ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                    .foregroundStyle(item.passed ? .green : .orange)
            }
        }
    }
}

extension DeviceMonitor {
    /// Reads the disk, power, and camera each time, so call it once per render.
    var recordingCheck: RecordingCheck {
        RecordingCheck.evaluate(RecordingCheck.currentInputs(
            camera: previewCamera, mic: snapshot.active(.microphone), sampleRates: snapshot.sampleRates
        ))
    }
}
