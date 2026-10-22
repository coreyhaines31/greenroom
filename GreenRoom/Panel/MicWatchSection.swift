import SwiftUI

struct MicWatchSection: View {
    let watch: MicWatch
    @State private var changing = false

    var body: some View {
        Section("Microphone check") {
            Toggle(isOn: Binding(get: { watch.isEnabled }, set: { enabled in
                changing = true
                Task {
                    await watch.setEnabled(enabled)
                    changing = false
                }
            })) {
                Text("Warn when an app starts with a silent mic")
                Text("Checks the mic an app opens for about four seconds (ten for Bluetooth). "
                     + "A warning stays visible during Focus without taking over your keyboard.")
            }
            .disabled(changing || !MicWatch.isSupported)
            Text(MicWatch.isSupported ? watch.status : "Requires macOS 14.2 or later.")
                .font(.caption).foregroundStyle(.secondary)
            Text("A quiet pause can also trigger a warning. Apps that keep their mic open "
                 + "get one check until they release it. Ignored apps are skipped.")
                .font(.caption).foregroundStyle(.secondary)
        }
    }
}
