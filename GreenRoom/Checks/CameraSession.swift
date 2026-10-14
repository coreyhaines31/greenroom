import AppKit
import AVFoundation
import Observation
import SwiftUI

/// `startRunning` blocks, so the session starts and stops on its own queue.
final class SessionBox: @unchecked Sendable {
    let session = AVCaptureSession()
    let queue = DispatchQueue(label: "com.greenroomformac.camera")
}

@MainActor
@Observable
final class CameraSession {
    @ObservationIgnored private let box = SessionBox()
    @ObservationIgnored private(set) var deviceID: String?
    @ObservationIgnored private var analyzer: FrameAnalyzer?
    /// One line about light and framing, while the preview runs.
    private(set) var advice: String?

    var session: AVCaptureSession { box.session }

    /// Every session change runs on the session's queue: AVFoundation doesn't allow
    /// reconfiguring on one thread while `startRunning` is in progress on another.
    func start(_ device: AVCaptureDevice) {
        let box = box
        if analyzer == nil {
            let analyzer = FrameAnalyzer(onAdvice: Self.adviceHandler { [weak self] in self?.advice = $0 })
            self.analyzer = analyzer
            box.queue.async {
                let output = AVCaptureVideoDataOutput()
                output.alwaysDiscardsLateVideoFrames = true
                output.videoSettings = [
                    kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_420YpCbCr8BiPlanarFullRange
                ]
                output.setSampleBufferDelegate(analyzer, queue: box.queue)
                box.session.beginConfiguration()
                if box.session.canAddOutput(output) { box.session.addOutput(output) }
                box.session.commitConfiguration()
            }
        }
        let newID = deviceID == device.uniqueID ? nil : device.uniqueID
        deviceID = device.uniqueID
        box.queue.async {
            if let newID, let device = AVCaptureDevice(uniqueID: newID),
               let input = try? AVCaptureDeviceInput(device: device) {
                box.session.beginConfiguration()
                box.session.inputs.forEach(box.session.removeInput)
                if box.session.canAddInput(input) { box.session.addInput(input) }
                box.session.commitConfiguration()
            }
            if !box.session.isRunning { box.session.startRunning() }
        }
    }

    func stop() {
        let box = box
        box.queue.async { if box.session.isRunning { box.session.stopRunning() } }
        advice = nil
    }

    /// The analyzer calls back on the camera queue, so the handler is made outside the main
    /// actor and hops back to it.
    nonisolated static func adviceHandler(
        _ set: @escaping @MainActor @Sendable (String?) -> Void
    ) -> @Sendable (String?) -> Void {
        { advice in DispatchQueue.main.async { MainActor.assumeIsolated { set(advice) } } }
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
