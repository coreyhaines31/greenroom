import GreenRoomCore
import SwiftUI

/// "Ready to record?": camera format, mic quality, disk space, and power. Collapsed until you
/// open it, since it only matters before a recording.
struct RecordingSection: View {
    let monitor: DeviceMonitor
    @AppStorage("showRecordingCheck") private var expanded = false

    var body: some View {
        // Reads the disk, power, and camera once per render.
        let check = monitor.recordingCheck
        VStack(alignment: .leading, spacing: 8) {
            Button {
                expanded.toggle()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: expanded ? "chevron.down" : "chevron.right").font(.caption2.weight(.semibold))
                    Text(expanded ? "Ready to record?" : "Ready to record? \(summary(check))")
                }
                .font(.caption).foregroundStyle(.secondary)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            if expanded {
                RecordingChecklist(check: check)
            }
        }
    }

    private func summary(_ check: RecordingCheck) -> String {
        let problems = check.items.filter { !$0.passed }.count
        return problems == 0 ? "Yes" : "\(problems) to check"
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
