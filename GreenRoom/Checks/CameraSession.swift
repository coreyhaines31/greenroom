import AppKit
import AVFoundation
import GreenRoomCore
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
    @ObservationIgnored private var monitorOutput: AVCaptureVideoDataOutput?
    @ObservationIgnored private var pendingOrientation = PictureOrientation()
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
            analyzer.orientation = pendingOrientation
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

    /// How the picture is shown, for framing advice. The panel is upright and mirrored; the
    /// record preview sets its own turn and mirror while it's open.
    func setOrientation(_ orientation: PictureOrientation) {
        analyzer?.orientation = orientation
        pendingOrientation = orientation
    }

    /// Sends frames to the record preview's tools, `width` wide and as tall as the camera's
    /// aspect. Attaching again replaces the earlier feed.
    func attachMonitor(_ feed: MonitorFeed, width: Int, aspect: Double) {
        detachMonitor()
        let output = AVCaptureVideoDataOutput()
        output.alwaysDiscardsLateVideoFrames = true
        let height = aspect > 0 ? Int((Double(width) / aspect / 2).rounded()) * 2 : width * 9 / 16
        output.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_420YpCbCr8BiPlanarFullRange,
            kCVPixelBufferWidthKey as String: width, kCVPixelBufferHeightKey as String: height
        ]
        output.setSampleBufferDelegate(feed, queue: feed.queue)
        monitorOutput = output
        let box = box
        box.queue.async {
            box.session.beginConfiguration()
            if box.session.canAddOutput(output) { box.session.addOutput(output) }
            box.session.commitConfiguration()
        }
    }

    func detachMonitor() {
        guard let output = monitorOutput else { return }
        monitorOutput = nil
        let box = box
        box.queue.async {
            box.session.beginConfiguration()
            box.session.removeOutput(output)
            box.session.commitConfiguration()
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

/// Mirrored by default, like looking in a mirror. Call apps show you to yourself the same way.
struct CameraPreview: NSViewRepresentable {
    let session: AVCaptureSession
    /// Fill crops to the panel's 16:9 box. Fit shows the whole frame, as it will be recorded.
    var gravity: AVLayerVideoGravity = .resizeAspectFill
    var orientation = PictureOrientation()

    func makeNSView(context: Context) -> PreviewLayerView {
        PreviewLayerView(session: session, gravity: gravity)
    }

    func updateNSView(_ view: PreviewLayerView, context: Context) {
        view.orientation = orientation
    }
}

/// Turns the picture on the layer, so the camera keeps sending frames as they are. A sideways
/// turn lays the layer out tall, so the turned picture fits the view.
final class PreviewLayerView: NSView {
    private let preview: AVCaptureVideoPreviewLayer
    var orientation = PictureOrientation() {
        didSet { if orientation != oldValue { arrange() } }
    }

    init(session: AVCaptureSession, gravity: AVLayerVideoGravity) {
        preview = AVCaptureVideoPreviewLayer(session: session)
        preview.videoGravity = gravity
        super.init(frame: .zero)
        layer = CALayer()
        wantsLayer = true
        layer?.addSublayer(preview)
        arrange()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        arrange()
    }

    private func arrange() {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        let size = bounds.size
        preview.bounds = CGRect(
            origin: .zero,
            size: orientation.isSideways ? CGSize(width: size.height, height: size.width) : size
        )
        preview.position = CGPoint(x: bounds.midX, y: bounds.midY)
        preview.setAffineTransform(Self.transform(for: orientation))
        CATransaction.commit()
    }

    /// Clockwise turns, then the mirror. Layers turn counterclockwise for positive angles.
    nonisolated static func transform(for orientation: PictureOrientation) -> CGAffineTransform {
        let turn = CGAffineTransform(rotationAngle: -CGFloat(orientation.quarterTurns) * .pi / 2)
        return orientation.mirrored ? turn.concatenating(CGAffineTransform(scaleX: -1, y: 1)) : turn
    }
}
