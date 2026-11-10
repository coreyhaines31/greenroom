import Foundation

/// How the `greenroom` command prints JSON. Every path uses one encoder, so dates are always ISO 8601.
public enum JSONOutput {
    public static var encoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }

    public static func string<T: Encodable>(_ value: T) -> String? {
        (try? encoder.encode(value)).flatMap { String(bytes: $0, encoding: .utf8) }
    }

    /// `value`'s fields stay at the top level, with `extra` added under `key`.
    public static func string<T: Encodable, U: Encodable>(_ value: T, adding key: String, _ extra: U) -> String? {
        guard let base = try? JSONSerialization.jsonObject(with: encoder.encode(value)) as? [String: Any],
              let added = try? JSONSerialization.jsonObject(with: encoder.encode(extra)) else { return nil }
        var merged = base
        merged[key] = added
        let data = try? JSONSerialization.data(withJSONObject: merged, options: [.prettyPrinted, .sortedKeys])
        return data.flatMap { String(bytes: $0, encoding: .utf8) }
    }
}
