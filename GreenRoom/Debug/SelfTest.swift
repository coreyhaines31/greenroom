#if DEBUG
import AppKit
import AVFoundation
import GreenRoomCore

/// `--self-test <path>`: runs the live checks for a few seconds without the panel and writes
/// what happened as JSON, so the camera and mic can be verified from a terminal.
final class FrameCounter: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate, @unchecked Sendable {
    private let lock = NSLock()
    private var count = 0
    var frames: Int { lock.withLock { count } }

    func captureOutput(
        _ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection
    ) {
        lock.withLock { count += 1 }
    }
}

@MainActor
enum SelfTest {
    static func run(monitor: DeviceMonitor, writingTo path: String) {
        Task {
            let camera = await AVCaptureDevice.requestAccess(for: .video)
            let mic = await AVCaptureDevice.requestAccess(for: .audio)
            let device = monitor.previewCamera
            let counter = FrameCounter()
            let box = SessionBox()
            if camera, let device, let capture = Cameras.captureDevice(for: device),
               let input = try? AVCaptureDeviceInput(device: capture) {
                let output = AVCaptureVideoDataOutput()
                output.setSampleBufferDelegate(counter, queue: box.queue)
                box.session.addInput(input)
                box.session.addOutput(output)
                box.queue.async { box.session.startRunning() }
            }
            let meter = MicMeter()
            if mic { meter.start() }
            var peak: Float = 0
            for _ in 0..<40 {
                try? await Task.sleep(for: .milliseconds(100))
                peak = max(peak, meter.level)
            }
            meter.stop()
            box.queue.async { box.session.stopRunning() }
            let result: [String: Any] = [
                "cameraAccess": camera, "micAccess": mic,
                "camera": device?.name ?? "none", "cameraFrames": counter.frames,
                "microphone": monitor.snapshot.active(.microphone)?.name ?? "none", "micPeakLevel": peak
            ]
            if let data = try? JSONSerialization.data(withJSONObject: result, options: [.prettyPrinted, .sortedKeys]) {
                try? data.write(to: URL(fileURLWithPath: path))
            }
            NSApp.terminate(nil)
        }
    }
}
#endif
