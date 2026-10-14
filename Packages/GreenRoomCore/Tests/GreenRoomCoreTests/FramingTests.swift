import CoreGraphics
@testable import GreenRoomCore
import Testing

struct FramingTests {
    let centered = CGRect(x: 0.4, y: 0.4, width: 0.2, height: 0.3)

    @Test func quietWhenWellLitAndCentered() {
        #expect(Framing.advice(faces: [centered], brightness: 0.5, faceBrightness: 0.5) == nil)
    }

    @Test func flagsACoveredLensAndDarkRooms() {
        #expect(Framing.advice(faces: [], brightness: 0.01, faceBrightness: nil)?.contains("lens covered") == true)
        #expect(Framing.advice(faces: [], brightness: 0.1, faceBrightness: nil)?.hasPrefix("It's dark") == true)
        #expect(Framing.advice(faces: [], brightness: 0.5, faceBrightness: nil) == nil)
    }

    @Test func flagsBacklighting() {
        let advice = Framing.advice(faces: [centered], brightness: 0.6, faceBrightness: 0.2)
        #expect(advice?.hasPrefix("You're backlit") == true)
    }

    @Test func flagsFramingAsSeenInTheMirror() {
        // Vision's x is the camera's view. The preview is mirrored, so a face at raw x 0.1 shows on the right.
        func advice(_ face: CGRect) -> String? { Framing.advice(faces: [face], brightness: 0.5, faceBrightness: 0.5) }
        #expect(advice(CGRect(x: 0.05, y: 0.4, width: 0.2, height: 0.3))?.hasPrefix("You're off to the right") == true)
        #expect(advice(CGRect(x: 0.4, y: 0.75, width: 0.2, height: 0.3))?.hasPrefix("The top of your head") == true)
        #expect(advice(CGRect(x: 0.45, y: 0.4, width: 0.08, height: 0.1))?.hasPrefix("You're far") == true)
    }
}
