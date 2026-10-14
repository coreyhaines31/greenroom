import AVFoundation
import GreenRoomCore
import Vision

/// Looks at about one camera frame a second for faces and light, on the camera's own queue,
/// and reports one line of advice. Frames are read and dropped; nothing is kept.
final class FrameAnalyzer: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate, @unchecked Sendable {
    private let onAdvice: @Sendable (String?) -> Void
    private var last = Date.distantPast

    init(onAdvice: @escaping @Sendable (String?) -> Void) {
        self.onAdvice = onAdvice
    }

    func captureOutput(
        _ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection
    ) {
        guard Date.now.timeIntervalSince(last) >= 1, let pixels = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return
        }
        last = .now
        let request = VNDetectFaceRectanglesRequest()
        try? VNImageRequestHandler(cvPixelBuffer: pixels, orientation: .up).perform([request])
        let faces = request.results?.map(\.boundingBox) ?? []
        let largest = faces.max { $0.width * $0.height < $1.width * $1.height }
        let advice = Framing.advice(
            faces: faces, brightness: Self.brightness(pixels, in: nil),
            faceBrightness: largest.map { Self.brightness(pixels, in: $0) }
        )
        onAdvice(advice)
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
