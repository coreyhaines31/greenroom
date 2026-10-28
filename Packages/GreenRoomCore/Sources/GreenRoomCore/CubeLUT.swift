import Foundation

/// A 3D color lookup table from a `.cube` file, such as Sony's S-Log3 to Rec. 709. Red
/// changes fastest, as in the file and as Core Image's color cube expects.
public struct CubeLUT: Sendable, Equatable {
    public enum ParseError: Error, Equatable {
        case missingSize
        case oneDimensional
        case unsupportedDomain
        case badLine(String)
        case wrongCount(expected: Int, found: Int)
        case tooLarge
    }

    /// Core Image's color cube takes up to 128 a side; real LUTs are 33 or 65.
    public static let largestSize = 128

    public let title: String?
    /// Entries along each side.
    public let size: Int
    /// RGBA, `size` cubed entries.
    public let rgba: [Float]

    public init(parsing text: String) throws {
        var title: String?
        var size: Int?
        var rgba: [Float] = []
        for rawLine in text.split(whereSeparator: \.isNewline) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            guard !line.isEmpty, !line.hasPrefix("#") else { continue }
            let parts = line.split(whereSeparator: \.isWhitespace)
            switch parts[0] {
            case "TITLE":
                title = line.dropFirst(5).trimmingCharacters(in: CharacterSet(charactersIn: "\" "))
            case "LUT_3D_SIZE":
                let value = try Self.size(parts)
                size = value
                rgba.reserveCapacity(value * value * value * 4)
            case "LUT_1D_SIZE":
                throw ParseError.oneDimensional
            case "DOMAIN_MIN", "DOMAIN_MAX":
                try Self.checkDomain(parts)
            default:
                rgba += try Self.entry(parts, line: line)
            }
        }
        guard let size else { throw ParseError.missingSize }
        let expected = size * size * size
        guard rgba.count == expected * 4 else { throw ParseError.wrongCount(expected: expected, found: rgba.count / 4) }
        self.title = title
        self.size = size
        self.rgba = rgba
    }

    /// A damaged file with a huge size must not reserve the memory for it.
    private static func size(_ parts: [Substring]) throws -> Int {
        guard parts.count == 2, let value = Int(parts[1]), value > 1 else { throw ParseError.missingSize }
        guard value <= largestSize else { throw ParseError.tooLarge }
        return value
    }

    /// Only the usual 0 to 1 domain; tables for other ranges would show the wrong colors.
    private static func checkDomain(_ parts: [Substring]) throws {
        let expected: Float = parts[0] == "DOMAIN_MIN" ? 0 : 1
        guard parts.dropFirst().allSatisfy({ Float($0) == expected }) else { throw ParseError.unsupportedDomain }
    }

    /// One RGBA entry, or none for keywords like LUT_3D_INPUT_RANGE that don't change the table.
    private static func entry(_ parts: [Substring], line: String) throws -> [Float] {
        let values = parts.compactMap { Float($0) }
        if values.count == 3, parts.count == 3 { return values + [1] }
        if parts[0].first?.isLetter == true { return [] }
        throw ParseError.badLine(line)
    }
}
