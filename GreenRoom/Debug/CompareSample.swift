#if DEBUG
import AppKit
import GreenRoomCore
import SwiftUI

/// `--render-compare <path>`: draws the mic comparison with sample levels, for checking its
/// layout without mic access.
@MainActor
enum CompareSample {
    static func write(to path: String) {
        let mics = [
            Device(id: "lapel", name: "Lapel Mic", kind: .microphone, transport: .usb),
            Device(id: "display", name: "Studio Display Microphone", kind: .microphone, transport: .display),
            Device(id: "mac", name: "MacBook Pro Microphone", kind: .microphone, transport: .builtIn),
            Device(id: "pods", name: "AirPods Pro", kind: .microphone, transport: .bluetooth)
        ]
        let view = MicComparison(
            mics: mics, active: mics[0], levels: ["lapel": 0.62, "display": 0.31, "mac": 0.24]
        ) { _ in }
            .padding(16)
            .frame(width: 340)
            .background(Color(nsColor: .windowBackgroundColor))
        let renderer = ImageRenderer(content: view)
        renderer.scale = 2
        guard let image = renderer.nsImage, let tiff = image.tiffRepresentation,
              let png = NSBitmapImageRep(data: tiff)?.representation(using: .png, properties: [:]) else { return }
        try? png.write(to: URL(fileURLWithPath: path))
    }
}
#endif
