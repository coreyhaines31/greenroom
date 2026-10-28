import AVFoundation
import GreenRoomCore
import ImageIO
import Vision

/// Looks at about one camera frame a second for faces and light, on the camera's own queue,
/// and reports one line of advice. Frames are read and dropped; nothing is kept.
final class FrameAnalyzer: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate, @unchecked Sendable {
    private let onAdvice: @Sendable (String?) -> Void
    private var last = Date.distantPast
    /// The first second or so after the camera starts is dark while exposure settles.
    private var startedAt = Date.distantPast
    static let warmUp: TimeInterval = 1.5
    /// Analysis runs on its own queue so it never holds up starting or stopping the camera.
    let queue = DispatchQueue(label: "com.greenroomformac.framing", qos: .utility)
    private let lock = NSLock()
    private var shown = PictureOrientation()

    /// How the picture is shown, so faces are found upright and left and right match the preview.
    var orientation: PictureOrientation {
        get { lock.withLock { shown } }
        set { lock.withLock { shown = newValue } }
    }

    /// Call when the camera starts, on `queue`.
    func reset() {
        startedAt = .now
        last = .now
    }

    init(onAdvice: @escaping @Sendable (String?) -> Void) {
        self.onAdvice = onAdvice
    }

    func captureOutput(
        _ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection
    ) {
        guard Date.now.timeIntervalSince(startedAt) >= Self.warmUp, Date.now.timeIntervalSince(last) >= 1,
              let pixels = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        last = .now
        let orientation = orientation
        let request = VNDetectFaceRectanglesRequest()
        try? VNImageRequestHandler(cvPixelBuffer: pixels, orientation: Self.vision(orientation)).perform([request])
        let faces = request.results?.map(\.boundingBox) ?? []
        let largest = faces.max { $0.width * $0.height < $1.width * $1.height }
        let advice = Framing.advice(
            faces: faces, brightness: Self.brightness(pixels, in: nil),
            faceBrightness: largest.map { Self.brightness(pixels, in: orientation.cameraRect(fromUpright: $0)) },
            mirrored: orientation.mirrored
        )
        onAdvice(advice)
    }

    /// The turn that makes the camera's frame upright. `.right` means turn it a quarter clockwise.
    static func vision(_ orientation: PictureOrientation) -> CGImagePropertyOrientation {
        switch orientation.quarterTurns {
        case 1: .right
        case 2: .down
        case 3: .left
        default: .up
        }
    }

    /// Average of the luma plane, sampled on a grid. `rect` is normalized with its origin at
    /// the bottom left, as Vision reports faces.
    static func brightness(_ pixels: CVPixelBuffer, in rect: CGRect?) -> Double {
        CVPixelBufferLockBaseAddress(pixels, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pixels, .readOnly) }
        let planar = CVPixelBufferIsPlanar(pixels)
        guard let base = planar ? CVPixelBufferGetBaseAddressOfPlane(pixels, 0) : CVPixelBufferGetBaseAddress(pixels)
        else { return 0.5 }
        let width = planar ? CVPixelBufferGetWidthOfPlane(pixels, 0) : CVPixelBufferGetWidth(pixels)
        let height = planar ? CVPixelBufferGetHeightOfPlane(pixels, 0) : CVPixelBufferGetHeight(pixels)
        let rowBytes = planar ? CVPixelBufferGetBytesPerRowOfPlane(pixels, 0) : CVPixelBufferGetBytesPerRow(pixels)
        let area = rect ?? CGRect(x: 0, y: 0, width: 1, height: 1)
        let minX = Int(area.minX * Double(width)), maxX = Int(area.maxX * Double(width))
        let minY = Int((1 - area.maxY) * Double(height)), maxY = Int((1 - area.minY) * Double(height))
        let bytes = base.assumingMemoryBound(to: UInt8.self)
        var total = 0, samples = 0
        for row in stride(from: max(minY, 0), to: min(maxY, height), by: 8) {
            for column in stride(from: max(minX, 0), to: min(maxX, width), by: 8) {
                total += Int(bytes[row * rowBytes + column])
                samples += 1
            }
        }
        return samples > 0 ? Double(total) / Double(samples) / 255 : 0.5
    }
}
