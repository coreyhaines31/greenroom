import CoreGraphics
import Foundation

/// How a camera's picture is turned for display: quarter turns clockwise, then an optional
/// left-right mirror on screen. A camera mounted sideways for vertical video needs one turn.
public struct PictureOrientation: Sendable, Equatable {
    public var quarterTurns: Int
    public var mirrored: Bool

    public init(quarterTurns: Int = 0, mirrored: Bool = true) {
        self.quarterTurns = ((quarterTurns % 4) + 4) % 4
        self.mirrored = mirrored
    }

    /// Sideways turns swap width and height.
    public var isSideways: Bool { quarterTurns % 2 == 1 }

    /// Width over height as shown, from the camera's own width over height.
    public func displayAspect(_ aspect: Double) -> Double {
        isSideways && aspect > 0 ? 1 / aspect : aspect
    }

    /// A normalized rectangle (origin bottom-left) in the turned, unmirrored picture, mapped
    /// back to the camera's own frame.
    public func cameraRect(fromUpright rect: CGRect) -> CGRect {
        switch quarterTurns {
        case 1: CGRect(x: 1 - rect.maxY, y: rect.minX, width: rect.height, height: rect.width)
        case 2: CGRect(x: 1 - rect.maxX, y: 1 - rect.maxY, width: rect.width, height: rect.height)
        case 3: CGRect(x: rect.minY, y: 1 - rect.maxX, width: rect.height, height: rect.width)
        default: rect
        }
    }

    /// The displayed column of a pixel at (`x`, `y`), counted from the top left of the
    /// camera's frame, and how many columns there are once it's turned.
    public func displayColumn(x: Int, y: Int, width: Int, height: Int) -> (column: Int, columns: Int) {
        let column: Int, columns: Int
        switch quarterTurns {
        case 1: (column, columns) = (height - 1 - y, height)
        case 2: (column, columns) = (width - 1 - x, width)
        case 3: (column, columns) = (y, height)
        default: (column, columns) = (x, width)
        }
        return (mirrored ? columns - 1 - column : column, columns)
    }
}

/// A luma histogram and waveform from one frame, each scaled so its busiest cell is 1.
public struct LumaScopes: Sendable, Equatable {
    public static let histogramBins = 64
    public static let waveformColumns = 96
    public static let waveformLevels = 48

    /// Dark to bright.
    public var histogram: [Float]
    /// Column by column as displayed, each column `waveformLevels` long from dark to bright.
    public var waveform: [Float]
    /// Share of sampled pixels at 99% or above.
    public var clipped: Double

    public init(histogram: [Float], waveform: [Float], clipped: Double) {
        self.histogram = histogram
        self.waveform = waveform
        self.clipped = clipped
    }

    /// Reads an 8-bit full-range luma plane every `step` pixels.
    public init(
        luma: UnsafePointer<UInt8>, width: Int, height: Int, rowBytes: Int,
        orientation: PictureOrientation, step: Int = 2
    ) {
        var histogram = [Float](repeating: 0, count: Self.histogramBins)
        var waveform = [Float](repeating: 0, count: Self.waveformColumns * Self.waveformLevels)
        var clipped = 0, samples = 0
        let clipLevel = UInt8(0.99 * 255)
        for y in stride(from: 0, to: height, by: max(step, 1)) {
            for x in stride(from: 0, to: width, by: max(step, 1)) {
                let value = luma[y * rowBytes + x]
                histogram[Int(value) * Self.histogramBins / 256] += 1
                let (column, columns) = orientation.displayColumn(x: x, y: y, width: width, height: height)
                let bin = column * Self.waveformColumns / columns
                waveform[bin * Self.waveformLevels + Int(value) * Self.waveformLevels / 256] += 1
                if value >= clipLevel { clipped += 1 }
                samples += 1
            }
        }
        self.histogram = Self.normalized(histogram)
        self.waveform = Self.normalized(waveform)
        self.clipped = samples > 0 ? Double(clipped) / Double(samples) : 0
    }

    /// Scaled by the square root, so a few busy cells don't flatten the rest.
    private static func normalized(_ counts: [Float]) -> [Float] {
        guard let top = counts.max(), top > 0 else { return counts }
        let scale = top.squareRoot()
        return counts.map { $0.squareRoot() / scale }
    }
}

/// The ARRI-style false color scale: grays everywhere except a few levels that matter.
public enum FalseColor {
    /// From 0 to 1.
    public struct RGB: Sendable, Equatable {
        public let red: Double, green: Double, blue: Double

        public init(_ red: Double, _ green: Double, _ blue: Double) {
            (self.red, self.green, self.blue) = (red, green, blue)
        }
    }

    public struct Band: Sendable, Equatable {
        /// Up to this luma, from 0 to 1.
        public let upTo: Double
        /// Nil shows the level as gray.
        public let color: RGB?
        public let label: String
    }

    public static let bands: [Band] = [
        Band(upTo: 0.025, color: RGB(0.55, 0.1, 0.85), label: "Crushed"),
        Band(upTo: 0.04, color: RGB(0.1, 0.35, 1), label: "Near black"),
        Band(upTo: 0.405, color: nil, label: ""),
        Band(upTo: 0.445, color: RGB(0.2, 0.8, 0.25), label: "Middle gray"),
        Band(upTo: 0.54, color: nil, label: ""),
        Band(upTo: 0.58, color: RGB(1, 0.45, 0.7), label: "Skin"),
        Band(upTo: 0.97, color: nil, label: ""),
        Band(upTo: 0.99, color: RGB(1, 0.9, 0.1), label: "Near white"),
        Band(upTo: 1.01, color: RGB(1, 0.1, 0.1), label: "Clipped")
    ]

    /// The color shown for a luma from 0 to 1.
    public static func color(forLuma luma: Double) -> RGB {
        let band = bands.first { luma < $0.upTo } ?? bands[bands.count - 1]
        return band.color ?? RGB(luma, luma, luma)
    }

    /// A lookup row of `count` RGBA pixels, dark to bright, for a color map filter.
    public static func lookupRow(count: Int = 256) -> [UInt8] {
        (0..<count).flatMap { index -> [UInt8] in
            let rgb = color(forLuma: Double(index) / Double(count - 1))
            return [rgb.red, rgb.green, rgb.blue].map { UInt8(($0 * 255).rounded()) } + [255]
        }
    }
}
