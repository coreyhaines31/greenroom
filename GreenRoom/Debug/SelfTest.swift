#if DEBUG
import AppKit
import AVFoundation
import GreenRoomCore
import Vision

/// `--self-test <path>`: runs the live checks for a few seconds without the panel and writes
/// what happened as JSON, so the camera and mic can be verified from a terminal.
final class FrameCounter: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate, @unchecked Sendable {
    private let lock = NSLock()
    private var count = 0
    private var framing: String?
    var frames: Int { lock.withLock { count } }
    var advice: String { lock.withLock { framing ?? "none" } }
    private var measured = ""
    var measurements: String { lock.withLock { measured } }
    private lazy var analyzer = FrameAnalyzer { [weak self] advice in
        guard let self else { return }
        lock.withLock { framing = advice }
    }

    func captureOutput(
        _ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection
    ) {
        let frame = lock.withLock { count += 1; return count }
        analyzer.captureOutput(output, didOutput: sampleBuffer, from: connection)
        if frame == 60, let pixels = CMSampleBufferGetImageBuffer(sampleBuffer) {
            let request = VNDetectFaceRectanglesRequest()
            try? VNImageRequestHandler(cvPixelBuffer: pixels, orientation: .up).perform([request])
            let faces = request.results?.map(\.boundingBox) ?? []
            let face = faces.first.map { String(format: "x %.2f y %.2f h %.2f", $0.midX, $0.midY, $0.height) } ?? "none"
            let text = String(format: "brightness %.2f, faces %d, face %@", FrameAnalyzer.brightness(pixels, in: nil),
                              faces.count, face)
            lock.withLock { measured = text }
        }
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
                output.videoSettings = [
                    kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_420YpCbCr8BiPlanarFullRange
                ]
                output.setSampleBufferDelegate(counter, queue: box.queue)
                box.session.addInput(input)
                box.session.addOutput(output)
                box.queue.async { box.session.startRunning() }
            }
            let meter = MicMeter()
            let inputs = InputMeters()
            if mic {
                meter.start()
                inputs.start(monitor.snapshot.devices(.microphone))
            }
            var peak: Float = 0
            var comparePeaks: [String: Float] = [:]
            for _ in 0..<40 {
                try? await Task.sleep(for: .milliseconds(100))
                peak = max(peak, meter.level)
                for device in monitor.snapshot.devices(.microphone) {
                    guard let level = inputs.levels[device.id] else { continue }
                    comparePeaks[device.name] = max(comparePeaks[device.name] ?? 0, level)
                }
            }
            meter.stop()
            inputs.stop()
            let recordedSeconds = mic ? await recordTwoSeconds() : 0
            box.queue.async { box.session.stopRunning() }
            let result: [String: Any] = [
                "cameraAccess": camera, "micAccess": mic,
                "camera": device?.name ?? "none", "cameraFrames": counter.frames,
                "microphone": monitor.snapshot.active(.microphone)?.name ?? "none", "micPeakLevel": peak,
                "recordedSeconds": recordedSeconds, "comparePeaks": comparePeaks, "framingAdvice": counter.advice,
                "framingMeasured": counter.measurements
            ]
            if let data = try? JSONSerialization.data(withJSONObject: result, options: [.prettyPrinted, .sortedKeys]) {
                try? data.write(to: URL(fileURLWithPath: path))
            }
            NSApp.terminate(nil)
        }
    }

    /// The Hear Yourself recording path, without playing anything back.
    static func recordTwoSeconds() async -> Double {
        let recording = PlaybackTest.Recording()
        let recorder = AVAudioEngine()
        let format = recorder.inputNode.outputFormat(forBus: 0)
        guard format.sampleRate > 0 else { return 0 }
        let tap = PlaybackTest.tap(into: recording)
        recorder.inputNode.installTap(onBus: 0, bufferSize: 4096, format: format, block: tap)
        try? recorder.start()
        try? await Task.sleep(for: .seconds(2))
        recorder.inputNode.removeTap(onBus: 0)
        recorder.stop()
        let frames = recording.all.reduce(0.0) { $0 + Double($1.frameLength) }
        return frames / format.sampleRate
    }
}
#endif
