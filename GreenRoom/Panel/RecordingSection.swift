import GreenRoomCore
import SwiftUI

/// "Ready to record?": camera format, mic quality, disk space, and power. Collapsed until you
/// open it, since it only matters before a recording.
struct RecordingSection: View {
    let monitor: DeviceMonitor
    @AppStorage("showRecordingCheck") private var expanded = false

    var body: some View {
        DisclosureGroup(isExpanded: $expanded) {
            VStack(alignment: .leading, spacing: 6) {
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
            .padding(.top, 6)
        } label: {
            Text(expanded ? "Ready to record?" : "Ready to record? \(summary)")
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    private var check: RecordingCheck {
        RecordingCheck.evaluate(RecordingCheck.currentInputs(
            camera: monitor.previewCamera, mic: monitor.snapshot.active(.microphone),
            sampleRates: monitor.snapshot.sampleRates
        ))
    }

    private var summary: String {
        let problems = check.items.filter { !$0.passed }.count
        return problems == 0 ? "Yes" : "\(problems) to check"
    }
}
