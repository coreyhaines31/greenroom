import SwiftUI

/// Lines over the record preview to help frame a shot. None of them are recorded.
enum CompositionGuide: String, CaseIterable, Identifiable {
    case thirds, center, safeAreas, vertical, square

    var id: String { rawValue }

    var title: String {
        switch self {
        case .thirds: "Rule of Thirds"
        case .center: "Center Mark"
        case .safeAreas: "Safe Areas"
        case .vertical: "Vertical Crop (9:16)"
        case .square: "Square Crop (1:1)"
        }
    }

    var help: String {
        switch self {
        case .thirds: "Splits the frame in thirds. Put your eyes near the top line."
        case .center: "Marks the middle of the frame, to center yourself or what you're showing."
        case .safeAreas:
            "Keep text inside the inner box and anything important inside the outer one, so apps "
                + "and TVs don't cut it off."
        case .vertical: "What a Short, Reel, or TikTok crop keeps. Stay inside it if you'll post vertical clips."
        case .square: "What a square crop keeps, for feeds that show posts 1:1."
        }
    }

    /// Stored as one comma-separated string, so @AppStorage can hold the set.
    static func decode(_ stored: String) -> Set<CompositionGuide> {
        Set(stored.split(separator: ",").compactMap { CompositionGuide(rawValue: String($0)) })
    }

    static func encode(_ guides: Set<CompositionGuide>) -> String {
        allCases.filter(guides.contains).map(\.rawValue).joined(separator: ",")
    }
}

/// Draws the guides over the picture itself, not the black bars around it.
struct CompositionOverlay: View {
    let guides: Set<CompositionGuide>
    /// Width over height of the camera's frame.
    let aspect: CGFloat

    var body: some View {
        Canvas { context, size in
            let picture = Self.fit(aspect: aspect, in: size)
            let line = GraphicsContext.Shading.color(.white.opacity(0.55))
            if guides.contains(.square) {
                dimOutside(crop(picture, aspect: 1), of: picture, in: &context)
            }
            if guides.contains(.vertical) {
                dimOutside(crop(picture, aspect: 9.0 / 16.0), of: picture, in: &context)
            }
            // With a crop on, the other guides frame what the crop keeps.
            let frame = guides.contains(.vertical) ? crop(picture, aspect: 9.0 / 16.0)
                : guides.contains(.square) ? crop(picture, aspect: 1) : picture
            if guides.contains(.thirds) {
                var path = Path()
                for step in 1...2 {
                    let x = frame.minX + frame.width * CGFloat(step) / 3
                    let y = frame.minY + frame.height * CGFloat(step) / 3
                    path.move(to: CGPoint(x: x, y: frame.minY))
                    path.addLine(to: CGPoint(x: x, y: frame.maxY))
                    path.move(to: CGPoint(x: frame.minX, y: y))
                    path.addLine(to: CGPoint(x: frame.maxX, y: y))
                }
                context.stroke(path, with: line, lineWidth: 1)
            }
            if guides.contains(.center) {
                let arm = min(frame.width, frame.height) * 0.03
                var path = Path()
                path.move(to: CGPoint(x: frame.midX - arm, y: frame.midY))
                path.addLine(to: CGPoint(x: frame.midX + arm, y: frame.midY))
                path.move(to: CGPoint(x: frame.midX, y: frame.midY - arm))
                path.addLine(to: CGPoint(x: frame.midX, y: frame.midY + arm))
                context.stroke(path, with: line, lineWidth: 1.5)
            }
            if guides.contains(.safeAreas) {
                // Action safe is 93% of the frame, title safe 90% (SMPTE ST 2046-1).
                let dashed = StrokeStyle(lineWidth: 1, dash: [6, 4])
                for scale in [0.93, 0.9] {
                    let inset = frame.insetBy(dx: frame.width * (1 - scale) / 2, dy: frame.height * (1 - scale) / 2)
                    context.stroke(Path(inset), with: line, style: dashed)
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    /// The rectangle a picture of this aspect fills when fitted into `size`, centered.
    static func fit(aspect: CGFloat, in size: CGSize) -> CGRect {
        guard aspect > 0, size.width > 0, size.height > 0 else { return CGRect(origin: .zero, size: size) }
        let width = min(size.width, size.height * aspect)
        let height = width / aspect
        return CGRect(x: (size.width - width) / 2, y: (size.height - height) / 2, width: width, height: height)
    }

    /// A centered crop of the frame, full height when the crop is narrower.
    private func crop(_ frame: CGRect, aspect: CGFloat) -> CGRect {
        Self.fit(aspect: aspect, in: frame.size).offsetBy(dx: frame.minX, dy: frame.minY)
    }

    private func dimOutside(_ crop: CGRect, of frame: CGRect, in context: inout GraphicsContext) {
        var outside = Path(frame)
        outside.addRect(crop)
        context.fill(outside, with: .color(.black.opacity(0.5)), style: FillStyle(eoFill: true))
        context.stroke(Path(crop), with: .color(.white.opacity(0.7)), lineWidth: 1)
    }
}
