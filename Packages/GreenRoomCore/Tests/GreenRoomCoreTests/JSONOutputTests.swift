import Foundation
@testable import GreenRoomCore
import Testing

struct JSONOutputTests {
    struct Seen: Encodable { let lastSeen: Date }
    struct Extra: Encodable { let ready: Bool }

    let seen = Seen(lastSeen: Date(timeIntervalSince1970: 0))

    @Test func writesDatesAsISO8601() {
        #expect(JSONOutput.string(seen)?.contains("\"1970-01-01T00:00:00Z\"") == true)
    }

    @Test func addingAKeyKeepsTheSameDateFormat() throws {
        let text = try #require(JSONOutput.string(seen, adding: "recording", Extra(ready: true)))
        #expect(text.contains("\"lastSeen\" : \"1970-01-01T00:00:00Z\""))
        let object = try #require(JSONSerialization.jsonObject(with: Data(text.utf8)) as? [String: Any])
        #expect((object["recording"] as? [String: Any])?["ready"] as? Bool == true)
    }
}
