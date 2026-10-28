#if DEBUG
import AppKit
import AVFoundation
import CoreImage.CIFilterBuiltins
import GreenRoomCore
import SwiftUI
import Vision

/// `--capture-monitor <folder>`: runs the live camera through each monitor tool for a few
/// seconds, saves one picture per tool, and writes how many pictures a second each managed.
/// Needs a build signed like the installed app, so it shares its camera access.
@MainActor
enum LiveMonitorTest {
    private final class Tally: @unchecked Sendable {
        private let lock = NSLock()
        private var pictures = 0
        private var latest: CGImage?
        private var latestScopes: LumaScopes?

        func add(_ image: CGImage) { lock.withLock { pictures += 1; latest = image } }
        func add(_ scopes: LumaScopes) { lock.withLock { latestScopes = scopes } }

        func take() -> (count: Int, image: CGImage?) {
            lock.withLock {
                defer { pictures = 0; latest = nil }
                return (pictures, latest)
            }
        }

        var scopes: LumaScopes? { lock.withLock { latestScopes } }
    }

    /// Keeps the latest raw frame, to measure edge strength.
    private final class Grab: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate, @unchecked Sendable {
        private let lock = NSLock()
        private var image: CIImage?
        var latest: CIImage? { lock.withLock { image } }

        func captureOutput(
            _ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection
        ) {
            guard let pixels = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
            let copy = CIImage(cvPixelBuffer: pixels, options: [.colorSpace: NSNull()])
            lock.withLock { image = copy }
        }
    }

    /// Edge strength at a few percentiles, as the peaking filter sees it, so thresholds can
    /// be picked from a real picture.
    private static func edgePercentiles(_ image: CIImage) -> String {
        let scale: Float = 10
        let edges = CIFilter.edges()
        edges.inputImage = MonitorFeed.luma(image)
        edges.intensity = scale
        guard let output = edges.outputImage?.cropped(to: image.extent) else { return "no edges" }
        let width = Int(image.extent.width), height = Int(image.extent.height)
        var bytes = [UInt8](repeating: 0, count: width * height * 4)
        CIContext(options: [.workingColorSpace: NSNull(), .outputColorSpace: NSNull()]).render(
            output, toBitmap: &bytes, rowBytes: width * 4, bounds: image.extent, format: .RGBA8, colorSpace: nil)
        let values = stride(from: 0, to: bytes.count, by: 4).map { bytes[$0] }.sorted()
        return [0.5, 0.9, 0.95, 0.98, 0.99, 0.995].map { share in
            let value = Float(values[min(Int(Double(values.count) * share), values.count - 1)]) / 255 / scale
            return String(format: "p%.1f %.4f", share * 100, value)
        }.joined(separator: ", ")
    }

    /// Turns the frame a quarter counterclockwise, like a camera mounted on its side, then
    /// looks for faces with and without the preview's matching clockwise turn.
    private static func framingCheck(_ frame: CIImage) -> [String] {
        let sideways = frame.transformed(by: CGAffineTransform(rotationAngle: .pi / 2))
        let image = sideways.transformed(by: CGAffineTransform(
            translationX: -sideways.extent.minX, y: -sideways.extent.minY))
        var buffer: CVPixelBuffer?
        CVPixelBufferCreate(nil, Int(image.extent.width), Int(image.extent.height),
                            kCVPixelFormatType_420YpCbCr8BiPlanarFullRange,
                            [kCVPixelBufferIOSurfacePropertiesKey: [:]] as CFDictionary, &buffer)
        guard let buffer else { return ["framing: no buffer"] }
        let original = VNDetectFaceRectanglesRequest()
        try? VNImageRequestHandler(ciImage: frame, orientation: .up).perform([original])
        let truth = original.results?.first.map {
            String(format: "framing unturned camera: x %.2f y %.2f", $0.boundingBox.midX, $0.boundingBox.midY)
        } ?? "framing unturned camera: no face"
        CIContext(options: [.workingColorSpace: NSNull(), .outputColorSpace: NSNull()]).render(image, to: buffer)
        let orientations = [PictureOrientation(), PictureOrientation(quarterTurns: 1, mirrored: false)]
        return [truth] + orientations.map { orientation in
            let request = VNDetectFaceRectanglesRequest()
            try? VNImageRequestHandler(cvPixelBuffer: buffer, orientation: FrameAnalyzer.vision(orientation))
                .perform([request])
            let faces = request.results?.map(\.boundingBox) ?? []
            let face = faces.first.map { box -> String in
                let camera = orientation.cameraRect(fromUpright: box)
                return String(format: "upright x %.2f y %.2f, face brightness %.2f", box.midX, box.midY,
                              FrameAnalyzer.brightness(buffer, in: camera))
            } ?? "none"
            let faceBrightness = faces.first.map {
                FrameAnalyzer.brightness(buffer, in: orientation.cameraRect(fromUpright: $0))
            }
            let advice = Framing.advice(
                faces: faces, brightness: FrameAnalyzer.brightness(buffer, in: nil),
                faceBrightness: faceBrightness, mirrored: orientation.mirrored
            ) ?? "no advice"
            return "framing turns \(orientation.quarterTurns): faces \(faces.count), \(face); \(advice)"
        }
    }

    private struct Run {
        let name: String
        let tools: Set<MonitorTool>
        var sensitivity = PeakingSensitivity.medium
    }

    private static let runs = [
        Run(name: "monochrome", tools: [.monochrome]),
        Run(name: "zebras", tools: [.zebras]),
        Run(name: "false-color", tools: [.falseColor]),
        Run(name: "peaking-low", tools: [.peaking], sensitivity: .low),
        Run(name: "peaking-medium", tools: [.peaking]),
        Run(name: "peaking-high", tools: [.peaking], sensitivity: .high),
        Run(name: "everything", tools: [.histogram, .waveform, .zebras, .peaking, .monochrome])
    ]

    static func run(monitor: DeviceMonitor, writingTo folder: String) {
        Task {
            var report: [String] = []
            defer {
                let path = (folder as NSString).appendingPathComponent("report.txt")
                try? report.joined(separator: "\n").write(toFile: path, atomically: true, encoding: .utf8)
            }
            guard await AVCaptureDevice.requestAccess(for: .video) else {
                report.append("no camera access")
                return
            }
            try? await Task.sleep(for: .seconds(1))
            guard let device = monitor.previewCamera, let capture = Cameras.captureDevice(for: device),
                  let input = try? AVCaptureDeviceInput(device: capture) else {
                report.append("no camera")
                return
            }
            let size = CMVideoFormatDescriptionGetDimensions(capture.activeFormat.formatDescription)
            report.append("camera \(device.name) \(size.width)x\(size.height)")
            let tally = Tally()
            let feed = MonitorFeed(onPicture: { tally.add($0) }, onScopes: { tally.add($0) })
            let grab = Grab()
            let box = start(input, size: size, feed: feed, grab: grab)
            try? await Task.sleep(for: .seconds(2))
            if let frame = grab.latest {
                report.append("edges " + edgePercentiles(frame))
                report.append(contentsOf: framingCheck(frame))
            }
            for run in runs {
                feed.settings = MonitorSettings(
                    tools: run.tools, zebraLevel: 0.7, peakingSensitivity: run.sensitivity,
                    orientation: PictureOrientation(mirrored: false)
                )
                _ = tally.take()
                try? await Task.sleep(for: .seconds(3))
                let (count, image) = tally.take()
                report.append(String(format: "%@: %.1f pictures/s", run.name, Double(count) / 3))
                if let image { write(image, to: folder, name: run.name) }
            }
            box.queue.async { box.session.stopRunning() }
            if let scopes = tally.scopes {
                report.append(String(format: "clipped %.3f", scopes.clipped))
                writeScopes(scopes, to: folder)
            }
        }
    }

    /// The same 1280-wide frames the record preview's tools get, plus raw ones for measuring.
    private static func start(
        _ input: AVCaptureDeviceInput, size: CMVideoDimensions, feed: MonitorFeed, grab: Grab
    ) -> SessionBox {
        let aspect = size.height > 0 ? Double(size.width) / Double(size.height) : 16.0 / 9.0
        let box = SessionBox()
        let output = AVCaptureVideoDataOutput()
        output.alwaysDiscardsLateVideoFrames = true
        output.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_420YpCbCr8BiPlanarFullRange,
            kCVPixelBufferWidthKey as String: 1280,
            kCVPixelBufferHeightKey as String: Int((1280 / aspect / 2).rounded()) * 2
        ]
        output.setSampleBufferDelegate(feed, queue: feed.queue)
        let raw = AVCaptureVideoDataOutput()
        raw.videoSettings = output.videoSettings
        raw.setSampleBufferDelegate(grab, queue: DispatchQueue(label: "com.greenroomformac.grab"))
        box.session.addInput(input)
        box.session.addOutput(output)
        box.session.addOutput(raw)
        box.queue.async { box.session.startRunning() }
        return box
    }

    private static func write(_ image: CGImage, to folder: String, name: String) {
        let rep = NSBitmapImageRep(cgImage: image)
        try? rep.representation(using: .png, properties: [:])?
            .write(to: URL(fileURLWithPath: folder).appendingPathComponent("\(name).png"))
    }

    private static func writeScopes(_ scopes: LumaScopes, to folder: String) {
        let view = HStack(spacing: 16) {
            Canvas { context, size in
                MonitorScopes.drawLevels(in: context, size: size)
                MonitorScopes.drawHistogram(scopes, in: context, size: size)
            }
            .frame(width: 220, height: 80)
            Canvas { context, size in
                MonitorScopes.drawLevels(in: context, size: size)
                MonitorScopes.drawWaveform(scopes, in: context, size: size)
            }
            .frame(width: 220, height: 110)
        }
        .padding(10)
        .background(Color.black)
        let renderer = ImageRenderer(content: view)
        renderer.scale = 2
        if let image = renderer.cgImage { write(image, to: folder, name: "scopes") }
    }
}
#endif
