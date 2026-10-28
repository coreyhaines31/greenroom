import AVFoundation
import CoreImage.CIFilterBuiltins
import GreenRoomCore

/// Tools in the record preview for judging exposure and focus. None of them are recorded.
enum MonitorTool: String, CaseIterable, Identifiable {
    case histogram, waveform, zebras, falseColor, peaking, monochrome

    var id: String { rawValue }

    var title: String {
        switch self {
        case .histogram: "Histogram"
        case .waveform: "Waveform"
        case .zebras: "Zebras"
        case .falseColor: "False Color"
        case .peaking: "Focus Peaking"
        case .monochrome: "Monochrome"
        }
    }

    var help: String {
        switch self {
        case .histogram: "How much of the picture is at each brightness, dark on the left"
        case .waveform: "Brightness across the picture, left to right; the top line is clipping"
        case .zebras: "Stripes over anything brighter than the zebra level"
        case .falseColor: "Colors key levels: pink is skin, green is middle gray, red is clipped"
        case .peaking: "Outlines whatever is in sharp focus"
        case .monochrome: "Black and white, to judge focus and contrast"
        }
    }

    /// These change the picture itself; the others draw beside it.
    var changesPicture: Bool { ![.histogram, .waveform].contains(self) }

    /// Stored as one comma-separated string, so @AppStorage can hold the set.
    static func decode(_ stored: String) -> Set<MonitorTool> {
        Set(stored.split(separator: ",").compactMap { MonitorTool(rawValue: String($0)) })
    }

    static func encode(_ tools: Set<MonitorTool>) -> String {
        allCases.filter(tools.contains).map(\.rawValue).joined(separator: ",")
    }
}

enum PeakingColor: String, CaseIterable, Identifiable {
    case red, green, white

    var id: String { rawValue }
    var title: String { rawValue.capitalized }

    var ciColor: CIColor {
        switch self {
        case .red: CIColor(red: 1, green: 0.15, blue: 0.15)
        case .green: CIColor(red: 0.2, green: 1, blue: 0.3)
        case .white: CIColor(red: 1, green: 1, blue: 1)
        }
    }
}

enum PeakingSensitivity: String, CaseIterable, Identifiable {
    case low, medium, high

    var id: String { rawValue }
    var title: String { rawValue.capitalized }

    /// Edge strength an outline needs. Lower outlines softer detail too.
    var threshold: Float {
        switch self {
        case .low: 0.35
        case .medium: 0.22
        case .high: 0.12
        }
    }
}

struct MonitorSettings: Sendable, Equatable {
    var tools: Set<MonitorTool> = []
    /// Zebras stripe anything at or above this luma, from 0 to 1.
    var zebraLevel = 0.95
    var peakingColor = PeakingColor.red
    var peakingSensitivity = PeakingSensitivity.medium
    var orientation = PictureOrientation()

    var changesPicture: Bool { tools.contains { $0.changesPicture } }
    var wantsScopes: Bool { tools.contains(.histogram) || tools.contains(.waveform) }
}

/// Reads camera frames for the record preview's tools, on its own queue. Draws the changed
/// picture with Core Image and measures the scopes about ten times a second. Frames are read
/// and dropped; nothing is kept.
final class MonitorFeed: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate, @unchecked Sendable {
    let queue = DispatchQueue(label: "com.greenroomformac.monitor", qos: .userInteractive)
    private let lock = NSLock()
    private var current = MonitorSettings()
    private let onPicture: @Sendable (CGImage) -> Void
    private let onScopes: @Sendable (LumaScopes) -> Void
    private var lastScopes = Date.distantPast
    /// Values stay as the camera encodes them, so zebra and false color levels match what's recorded.
    private lazy var context = CIContext(options: [
        .workingColorSpace: NSNull(), .outputColorSpace: NSNull(), .cacheIntermediates: false
    ])

    init(onPicture: @escaping @Sendable (CGImage) -> Void, onScopes: @escaping @Sendable (LumaScopes) -> Void) {
        self.onPicture = onPicture
        self.onScopes = onScopes
    }

    var settings: MonitorSettings {
        get { lock.withLock { current } }
        set { lock.withLock { current = newValue } }
    }

    func captureOutput(
        _ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection
    ) {
        guard let pixels = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let settings = settings
        if settings.wantsScopes, Date.now.timeIntervalSince(lastScopes) >= 0.1 {
            lastScopes = .now
            if let scopes = Self.scopes(pixels, orientation: settings.orientation) { onScopes(scopes) }
        }
        if settings.changesPicture {
            let image = Self.picture(CIImage(cvPixelBuffer: pixels, options: [.colorSpace: NSNull()]),
                                     settings: settings)
            if let rendered = context.createCGImage(image, from: image.extent, format: .RGBA8,
                                                    colorSpace: CGColorSpace(name: CGColorSpace.sRGB)) {
                onPicture(rendered)
            }
        }
    }

    /// Reads the luma plane of a bi-planar frame.
    static func scopes(_ pixels: CVPixelBuffer, orientation: PictureOrientation) -> LumaScopes? {
        guard CVPixelBufferIsPlanar(pixels) else { return nil }
        CVPixelBufferLockBaseAddress(pixels, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pixels, .readOnly) }
        guard let base = CVPixelBufferGetBaseAddressOfPlane(pixels, 0) else { return nil }
        return LumaScopes(
            luma: base.assumingMemoryBound(to: UInt8.self),
            width: CVPixelBufferGetWidthOfPlane(pixels, 0), height: CVPixelBufferGetHeightOfPlane(pixels, 0),
            rowBytes: CVPixelBufferGetBytesPerRowOfPlane(pixels, 0), orientation: orientation, step: 4
        )
    }

    /// The camera's picture with the tools applied, turned and mirrored as shown.
    static func picture(_ camera: CIImage, settings: MonitorSettings) -> CIImage {
        let tools = settings.tools
        let luma = Self.luma(camera)
        var image = camera
        if tools.contains(.falseColor) {
            image = falseColor(luma)
        } else if tools.contains(.monochrome) {
            image = luma
        }
        if tools.contains(.zebras) {
            image = zebras(over: image, luma: luma, level: settings.zebraLevel)
        }
        if tools.contains(.peaking) {
            image = peaking(over: image, luma: luma, color: settings.peakingColor,
                            sensitivity: settings.peakingSensitivity)
        }
        return oriented(image, settings.orientation)
    }

    /// Rec. 709 luma in all three channels.
    static func luma(_ image: CIImage) -> CIImage {
        let weights = CIVector(x: 0.2126, y: 0.7152, z: 0.0722, w: 0)
        let filter = CIFilter.colorMatrix()
        filter.inputImage = image
        filter.rVector = weights
        filter.gVector = weights
        filter.bVector = weights
        return filter.outputImage ?? image
    }

    private static let falseColorRow: CIImage = {
        let row = FalseColor.lookupRow()
        return CIImage(bitmapData: Data(row), bytesPerRow: row.count, size: CGSize(width: row.count / 4, height: 1),
                       format: .RGBA8, colorSpace: nil)
    }()

    static func falseColor(_ luma: CIImage) -> CIImage {
        let filter = CIFilter.colorMap()
        filter.inputImage = luma
        filter.gradientImage = falseColorRow
        return filter.outputImage?.cropped(to: luma.extent) ?? luma
    }

    /// Diagonal black and white stripes, so they show over any color.
    static func zebras(over image: CIImage, luma: CIImage, level: Double) -> CIImage {
        let stripes = CIFilter.stripesGenerator()
        stripes.color0 = CIColor(red: 0, green: 0, blue: 0, alpha: 0.85)
        stripes.color1 = CIColor(red: 1, green: 1, blue: 1, alpha: 0.85)
        stripes.width = Float(max(image.extent.width / 240, 3))
        guard let pattern = stripes.outputImage?
            .transformed(by: CGAffineTransform(rotationAngle: .pi / 4))
            .cropped(to: image.extent) else { return image }
        return blend(pattern, over: image, where: threshold(luma, at: Float(level)))
    }

    static func peaking(
        over image: CIImage, luma: CIImage, color: PeakingColor, sensitivity: PeakingSensitivity
    ) -> CIImage {
        let edges = CIFilter.edges()
        edges.inputImage = luma
        edges.intensity = 1
        guard let found = edges.outputImage?.cropped(to: luma.extent) else { return image }
        let solid = CIImage(color: color.ciColor).cropped(to: image.extent)
        // One-pixel outlines vanish once the picture is scaled up to fill a screen.
        let thicken = CIFilter.morphologyMaximum()
        thicken.inputImage = threshold(Self.luma(found), at: sensitivity.threshold)
        thicken.radius = 1
        guard let mask = thicken.outputImage?.cropped(to: luma.extent) else { return image }
        return blend(solid, over: image, where: mask)
    }

    /// White where the image is at or above `level`, black elsewhere.
    private static func threshold(_ image: CIImage, at level: Float) -> CIImage {
        let filter = CIFilter.colorThreshold()
        filter.inputImage = image
        filter.threshold = level
        return filter.outputImage ?? image
    }

    private static func blend(_ top: CIImage, over image: CIImage, where mask: CIImage) -> CIImage {
        let filter = CIFilter.blendWithMask()
        filter.inputImage = top
        filter.backgroundImage = image
        filter.maskImage = mask
        return filter.outputImage?.cropped(to: image.extent) ?? image
    }

    /// Same turn and mirror as the live preview layer.
    static func oriented(_ image: CIImage, _ orientation: PictureOrientation) -> CIImage {
        let turned = image.transformed(by: PreviewLayerView.transform(for: orientation))
        return turned.transformed(by: CGAffineTransform(translationX: -turned.extent.minX, y: -turned.extent.minY))
    }
}
