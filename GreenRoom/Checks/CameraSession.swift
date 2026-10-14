import AppKit
import AVFoundation
import SwiftUI

/// `startRunning` blocks, so the session starts and stops on its own queue.
final class SessionBox: @unchecked Sendable {
    let session = AVCaptureSession()
    let queue = DispatchQueue(label: "com.greenroomformac.camera")
}

@MainActor
final class CameraSession {
    private let box = SessionBox()
    private(set) var deviceID: String?

    var session: AVCaptureSession { box.session }

    func start(_ device: AVCaptureDevice) {
        let box = box
        if deviceID != device.uniqueID {
            box.session.beginConfiguration()
            box.session.inputs.forEach(box.session.removeInput)
            if let input = try? AVCaptureDeviceInput(device: device), box.session.canAddInput(input) {
                box.session.addInput(input)
            }
            box.session.commitConfiguration()
            deviceID = device.uniqueID
        }
        box.queue.async { if !box.session.isRunning { box.session.startRunning() } }
    }

    func stop() {
        let box = box
        box.queue.async { if box.session.isRunning { box.session.stopRunning() } }
    }
}

/// Mirrored, like looking in a mirror. Call apps show you to yourself the same way.
struct CameraPreview: NSViewRepresentable {
    let session: AVCaptureSession

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        let layer = AVCaptureVideoPreviewLayer(session: session)
        layer.videoGravity = .resizeAspectFill
        layer.setAffineTransform(CGAffineTransform(scaleX: -1, y: 1))
        view.layer = layer
        view.wantsLayer = true
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}
