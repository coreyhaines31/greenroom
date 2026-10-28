@testable import GreenRoomCore
import Testing

struct CubeLUTTests {
    /// The identity table at size 2, red changing fastest.
    let identity = """
    # Made by hand
    TITLE "Identity"
    LUT_3D_SIZE 2
    DOMAIN_MIN 0.0 0.0 0.0
    DOMAIN_MAX 1.0 1.0 1.0

    0.0 0.0 0.0
    1.0 0.0 0.0
    0.0 1.0 0.0
    1.0 1.0 0.0
    0.0 0.0 1.0
    1.0 0.0 1.0
    0.0 1.0 1.0
    1.0 1.0 1.0
    """

    @Test func readsTitleSizeAndEntries() throws {
        let lut = try CubeLUT(parsing: identity)
        #expect(lut.title == "Identity")
        #expect(lut.size == 2)
        #expect(lut.rgba.count == 32)
        #expect(Array(lut.rgba[4..<8]) == [1, 0, 0, 1])
        #expect(Array(lut.rgba[28..<32]) == [1, 1, 1, 1])
    }

    @Test func rejectsTablesItCantApply() {
        #expect(throws: CubeLUT.ParseError.missingSize) { try CubeLUT(parsing: "0 0 0") }
        #expect(throws: CubeLUT.ParseError.oneDimensional) { try CubeLUT(parsing: "LUT_1D_SIZE 4") }
        // A huge size in a damaged file must not try to reserve the memory for it.
        #expect(throws: CubeLUT.ParseError.tooLarge) { try CubeLUT(parsing: "LUT_3D_SIZE 3000000") }
        #expect(throws: CubeLUT.ParseError.unsupportedDomain) {
            try CubeLUT(parsing: identity.replacingOccurrences(of: "DOMAIN_MAX 1.0 1.0 1.0", with: "DOMAIN_MAX 2 2 2"))
        }
        #expect(throws: CubeLUT.ParseError.wrongCount(expected: 8, found: 7)) {
            try CubeLUT(parsing: identity.replacingOccurrences(of: "0.0 1.0 1.0\n1.0 1.0 1.0", with: "0.0 1.0 1.0"))
        }
    }
}
