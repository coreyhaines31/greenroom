#if DEBUG
import AppKit
import CoreImage.CIFilterBuiltins
import GreenRoomCore
import SwiftUI

/// `--render-monitor <path>`: runs a made-up frame through each monitor tool and draws the
/// scopes, for checking them without camera access.
@MainActor
enum MonitorSample {
    static func write(to path: String) {
        let context = CIContext(options: [.workingColorSpace: NSNull(), .outputColorSpace: NSNull()])
        guard let pixels = samplePixels(context: context) else { return }
        let camera = CIImage(cvPixelBuffer: pixels, options: [.colorSpace: NSNull()])
        let plain = MonitorSettings(orientation: PictureOrientation(mirrored: false))
        var turned = plain
        turned.orientation = PictureOrientation(quarterTurns: 1, mirrored: false)
        let panels: [(String, MonitorSettings)] = [
            ("Plain", plain),
            ("Zebras 70%", with(plain) { $0.tools = [.zebras]; $0.zebraLevel = 0.7 }),
            ("False Color", with(plain) { $0.tools = [.falseColor] }),
            ("Focus Peaking", with(plain) { $0.tools = [.peaking] }),
            ("Monochrome + Peaking", with(plain) { $0.tools = [.monochrome, .peaking]; $0.peakingColor = .green }),
            ("Rotated Right", with(turned) { $0.tools = [.monochrome] })
        ]
        let images = panels.compactMap { title, settings -> (String, NSImage)? in
            let image = MonitorFeed.picture(camera, settings: settings)
            guard let cgImage = context.createCGImage(image, from: image.extent, format: .RGBA8,
                                                      colorSpace: CGColorSpace(name: CGColorSpace.sRGB))
            else { return nil }
            return (title, NSImage(cgImage: cgImage, size: image.extent.size))
        }
        let scopes = MonitorFeed.scopes(pixels, orientation: plain.orientation)
        let renderer = ImageRenderer(content: sheet(images, scopes: scopes))
        renderer.scale = 1
        guard let image = renderer.nsImage, let tiff = image.tiffRepresentation,
              let png = NSBitmapImageRep(data: tiff)?.representation(using: .png, properties: [:]) else { return }
        try? png.write(to: URL(fileURLWithPath: path))
    }

    private static func sheet(_ images: [(String, NSImage)], scopes: LumaScopes?) -> some View {
        let column = GridItem(.fixed(400))
        return VStack(alignment: .leading, spacing: 16) {
            LazyVGrid(columns: [column, column, column], spacing: 16) {
                ForEach(images, id: \.0) { title, image in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(title).font(.headline)
                        Image(nsImage: image).resizable().aspectRatio(contentMode: .fit).frame(height: 225)
                    }
                }
            }
            HStack(alignment: .top, spacing: 16) {
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
                FalseColorLegend().frame(width: 240)
            }
            .padding(10)
            .background(.black.opacity(0.55))
        }
        .padding(16)
        .background(Color(white: 0.15))
        .environment(\.colorScheme, .dark)
    }

    private static func with(
        _ settings: MonitorSettings, _ change: (inout MonitorSettings) -> Void
    ) -> MonitorSettings {
        var settings = settings
        change(&settings)
        return settings
    }

    /// A 1280x720 frame in the camera's pixel format: a gray ramp along the bottom, color bars
    /// above it, a sharp checkerboard and a soft blob for peaking, and a white block at the top
    /// left to check which way a turn goes.
    private static func samplePixels(context: CIContext) -> CVPixelBuffer? {
        let size = CGRect(x: 0, y: 0, width: 1280, height: 720)
        let ramp = CIFilter.linearGradient()
        ramp.point0 = CGPoint(x: 0, y: 0)
        ramp.point1 = CGPoint(x: 1280, y: 0)
        ramp.color0 = CIColor(red: 0, green: 0, blue: 0)
        ramp.color1 = CIColor(red: 1, green: 1, blue: 1)
        let bars: [CIColor] = [.white, .yellow, .cyan, .green, .magenta, .red, .blue]
        var image = (ramp.outputImage ?? CIImage.empty()).cropped(to: CGRect(x: 0, y: 0, width: 1280, height: 240))
        for (index, color) in bars.enumerated() {
            let bar = CIImage(color: color.withAlpha(0.75)).cropped(
                to: CGRect(x: CGFloat(index) * 1280 / 7, y: 240, width: 1280 / 7 + 1, height: 240))
            image = bar.composited(over: image)
        }
        let checker = CIFilter.checkerboardGenerator()
        checker.width = 16
        checker.color0 = .black
        checker.color1 = .white
        if let board = checker.outputImage?.cropped(to: CGRect(x: 500, y: 500, width: 280, height: 200)) {
            image = board.composited(over: image)
        }
        let blob = CIImage(color: CIColor(red: 0.6, green: 0.45, blue: 0.4))
            .cropped(to: CGRect(x: 900, y: 500, width: 280, height: 200))
            .applyingGaussianBlur(sigma: 30).cropped(to: CGRect(x: 860, y: 480, width: 360, height: 240))
        image = blob.composited(over: image)
        let marker = CIImage(color: .white).cropped(to: CGRect(x: 20, y: 600, width: 160, height: 100))
        let background = CIImage(color: CIColor(red: 0.3, green: 0.3, blue: 0.3))
        image = marker.composited(over: image).composited(over: background).cropped(to: size)
        var buffer: CVPixelBuffer?
        CVPixelBufferCreate(nil, 1280, 720, kCVPixelFormatType_420YpCbCr8BiPlanarFullRange,
                            [kCVPixelBufferIOSurfacePropertiesKey: [:]] as CFDictionary, &buffer)
        guard let buffer else { return nil }
        context.render(image, to: buffer)
        return buffer
    }
}

private extension CIColor {
    func withAlpha(_ alpha: CGFloat) -> CIColor { CIColor(red: red * alpha, green: green * alpha, blue: blue * alpha) }
}
#endif
