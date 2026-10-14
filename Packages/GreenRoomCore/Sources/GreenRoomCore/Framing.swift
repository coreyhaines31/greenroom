import CoreGraphics
import Foundation

/// One line under the camera preview about how you look: light first, then framing. Built from
/// face rectangles and brightness measured on the Mac; frames are never kept.
public enum Framing {
    /// - Parameters:
    ///   - faces: face rectangles in normalized camera coordinates (origin bottom-left), as
    ///     Vision reports them, before the preview's mirroring.
    ///   - brightness: average brightness of the frame, 0 to 1.
    ///   - faceBrightness: average brightness inside the largest face, if there is one.
    public static func advice(faces: [CGRect], brightness: Double, faceBrightness: Double?) -> String? {
        if brightness < 0.04 {
            return "The picture is almost black. Is the lens covered or the shutter closed?"
        }
        guard let face = faces.max(by: { $0.width * $0.height < $1.width * $1.height }) else {
            return brightness < 0.15 ? "It's dark. Add a light in front of you." : nil
        }
        if let faceBrightness, faceBrightness < 0.3, brightness - faceBrightness > 0.15 {
            return "You're backlit, so your face is dark. Face the window or a lamp instead."
        }
        if (faceBrightness ?? brightness) < 0.2 {
            return "Your face is dark. Add a light in front of you."
        }
        if face.maxY > 0.98 {
            return "The top of your head is cut off. Tilt the camera up or sit lower."
        }
        if face.height > 0.6 {
            return "You're very close to the camera. Sit back a little."
        }
        if face.height < 0.12 {
            return "You're far from the camera. Move closer."
        }
        // The preview is mirrored, so left and right are as you see them in it.
        let centerSeen = 1 - face.midX
        if centerSeen < 0.3 { return "You're off to the left. Move toward the middle." }
        if centerSeen > 0.7 { return "You're off to the right. Move toward the middle." }
        return nil
    }
}
