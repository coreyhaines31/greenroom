import CoreGraphics
@testable import GreenRoomCore
import Testing

struct MonitorScopesTests {
    @Test func turnsWrapAndSidewaysSwapsTheAspect() {
        #expect(PictureOrientation(quarterTurns: 5).quarterTurns == 1)
        #expect(PictureOrientation(quarterTurns: -1).quarterTurns == 3)
        #expect(PictureOrientation(quarterTurns: 1).displayAspect(16.0 / 9.0) == 9.0 / 16.0)
        #expect(PictureOrientation(quarterTurns: 2).displayAspect(16.0 / 9.0) == 16.0 / 9.0)
    }

    @Test func displayColumnFollowsTurnsThenMirror() {
        // A 4x2 frame; the pixel at the top left.
        func column(_ turns: Int, mirrored: Bool) -> (Int, Int) {
            let result = PictureOrientation(quarterTurns: turns, mirrored: mirrored)
                .displayColumn(x: 0, y: 0, width: 4, height: 2)
            return (result.column, result.columns)
        }
        #expect(column(0, mirrored: false) == (0, 4))
        #expect(column(0, mirrored: true) == (3, 4))
        // A clockwise turn puts the top left at the top right.
        #expect(column(1, mirrored: false) == (1, 2))
        #expect(column(2, mirrored: false) == (3, 4))
        #expect(column(3, mirrored: false) == (0, 2))
    }

    @Test func uprightRectsMapBackToTheCamerasFrame() {
        // A small box at the top left of the turned picture.
        let upright = CGRect(x: 0, y: 0.8, width: 0.1, height: 0.2)
        // A clockwise turn put the camera's top left at the picture's top right, so the
        // picture's top left came from the camera's bottom left.
        #expect(PictureOrientation(quarterTurns: 1).cameraRect(fromUpright: upright)
            == CGRect(x: 0, y: 0, width: 0.2, height: 0.1))
        #expect(PictureOrientation(quarterTurns: 2).cameraRect(fromUpright: upright)
            == CGRect(x: 0.9, y: 0, width: 0.1, height: 0.2))
        #expect(PictureOrientation(quarterTurns: 3).cameraRect(fromUpright: upright)
            == CGRect(x: 0.8, y: 0.9, width: 0.2, height: 0.1))
        #expect(PictureOrientation().cameraRect(fromUpright: upright) == upright)
    }

    @Test func histogramAndWaveformPlaceLevels() {
        // Left half black, right half white, two rows as wide as the waveform has columns.
        let width = LumaScopes.waveformColumns * 2, height = 2
        let pixels: [UInt8] = (0..<height).flatMap { _ in (0..<width).map { $0 < width / 2 ? 0 : 255 } }
        let scopes = pixels.withUnsafeBufferPointer { buffer in
            LumaScopes(luma: buffer.baseAddress!, width: width, height: height, rowBytes: width,
                       orientation: PictureOrientation(mirrored: false), step: 1)
        }
        #expect(scopes.histogram.first == 1)
        #expect(scopes.histogram.last == 1)
        #expect(scopes.histogram.dropFirst().dropLast().allSatisfy { $0 == 0 })
        #expect(scopes.clipped == 0.5)
        let levels = LumaScopes.waveformLevels
        let firstColumn = Array(scopes.waveform[0..<levels])
        let columns = LumaScopes.waveformColumns
        let lastColumn = Array(scopes.waveform[(columns - 1) * levels..<columns * levels])
        #expect(firstColumn.first ?? 0 > 0)
        #expect(lastColumn.last ?? 0 > 0)
    }

    @Test func falseColorMarksSkinMiddleGrayAndClipping() {
        #expect(FalseColor.color(forLuma: 0.3) == FalseColor.RGB(0.3, 0.3, 0.3))
        #expect(FalseColor.color(forLuma: 0.42) == FalseColor.RGB(0.2, 0.8, 0.25))
        #expect(FalseColor.color(forLuma: 0.56) == FalseColor.RGB(1, 0.45, 0.7))
        #expect(FalseColor.color(forLuma: 1) == FalseColor.RGB(1, 0.1, 0.1))
        #expect(FalseColor.color(forLuma: 0.01) == FalseColor.RGB(0.55, 0.1, 0.85))
        let row = FalseColor.lookupRow()
        #expect(row.count == 256 * 4)
        #expect(Array(row[(255 * 4)..<(256 * 4)]) == [255, 26, 26, 255])
    }
}
