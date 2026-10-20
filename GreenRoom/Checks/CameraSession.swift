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
    /// Callbacks already on their way when the camera stops shouldn't bring advice back.
    @ObservationIgnored private(set) var running = false

    var session: AVCaptureSession { box.session }

    /// Every session change runs on the session's queue: AVFoundation doesn't allow
    /// reconfiguring on one thread while `startRunning` is in progress on another.
    func start(_ device: AVCaptureDevice) {
        let box = box
        if analyzer == nil {
            let analyzer = FrameAnalyzer(onAdvice: Self.adviceHandler { [weak self] advice in
                guard let self, running else { return }
                self.advice = advice
            })
            self.analyzer = analyzer
            box.queue.async {
                let output = AVCaptureVideoDataOutput()
                output.alwaysDiscardsLateVideoFrames = true
                // Small frames are plenty to find a face and judge light, and cost far less.
                output.videoSettings = [
                    kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_420YpCbCr8BiPlanarFullRange,
                    kCVPixelBufferWidthKey as String: 640, kCVPixelBufferHeightKey as String: 360
                ]
                output.setSampleBufferDelegate(analyzer, queue: analyzer.queue)
                box.session.beginConfiguration()
                if box.session.canAddOutput(output) { box.session.addOutput(output) }
                box.session.commitConfiguration()
            }
        }
        running = true
        if deviceID != device.uniqueID { advice = nil }
        if let analyzer { analyzer.queue.async { analyzer.reset() } }
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
        running = false
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
    /// Fill crops to the panel's 16:9 box. Fit shows the whole frame, as it will be recorded.
    var gravity: AVLayerVideoGravity = .resizeAspectFill

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        let layer = AVCaptureVideoPreviewLayer(session: session)
        layer.videoGravity = gravity
        layer.setAffineTransform(CGAffineTransform(scaleX: -1, y: 1))
        view.layer = layer
        view.wantsLayer = true
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}
