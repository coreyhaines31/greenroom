import Foundation
@testable import GreenRoomCore
import Testing

struct CorruptFileTests {
    let folder = FileManager.default.temporaryDirectory.appending(path: "CorruptFileTests-\(UUID().uuidString)")
    let now = Date(timeIntervalSince1970: 0)

    init() throws {
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    }

    @Test func noHistoryFileMeansEmptyHistory() throws {
        #expect(Storage.loadHistory(from: folder.appending(path: "history.json"), now: now) == DeviceHistory())
        #expect(try FileManager.default.contentsOfDirectory(atPath: folder.path).isEmpty)
    }

    @Test func movesACorruptHistoryFileAsideInsteadOfLosingIt() throws {
        let url = folder.appending(path: "history.json")
        let bad = Data("{\"records\": [not json".utf8)
        try bad.write(to: url)
        #expect(Storage.loadHistory(from: url, now: now) == DeviceHistory())
        #expect(!FileManager.default.fileExists(atPath: url.path))
        let backup = folder.appending(path: "history.json.corrupt-19700101T000000Z")
        #expect(try Data(contentsOf: backup) == bad)
    }

    @Test func keepsCorruptSetupsUnderABackupKey() throws {
        let defaults = try #require(UserDefaults(suiteName: "CorruptFileTests-\(UUID().uuidString)"))
        let bad = Data("not setups".utf8)
        defaults.set(bad, forKey: "setups")
        #expect(Storage.loadSetups(defaults, now: now).isEmpty)
        #expect(defaults.data(forKey: "setups.corrupt-19700101T000000Z") == bad)
        #expect(defaults.data(forKey: "setups") == nil)
    }
}
