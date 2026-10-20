import Foundation

/// File-based input/output avoids URL escaping and keeps the app responsive while Shortcuts runs.
enum HoldShortcut {
    static let name = "Green Room Hold Calls"

    static func run(_ input: String) async throws -> String {
        try await Task.detached(priority: .utility) { try runBlocking(input) }.value
    }

    private static func runBlocking(_ input: String) throws -> String {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let source = directory.appendingPathComponent("input.txt")
        let output = directory.appendingPathComponent("output.txt")
        let errors = directory.appendingPathComponent("errors.txt")
        try Data(input.utf8).write(to: source)
        FileManager.default.createFile(atPath: errors.path, contents: nil)
        let errorHandle = try FileHandle(forWritingTo: errors)
        defer { try? errorHandle.close() }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/shortcuts")
        process.arguments = ["run", name, "--input-path", source.path, "--output-path", output.path]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = errorHandle
        let finished = DispatchSemaphore(value: 0)
        process.terminationHandler = { _ in finished.signal() }
        try process.run()
        guard finished.wait(timeout: .now() + 20) == .success else {
            if process.isRunning { process.terminate() }
            throw Failure(message: "Shortcuts took too long. Open Shortcuts to check for a permission prompt.")
        }
        guard process.terminationStatus == 0 else {
            let detail = (try? String(contentsOf: errors, encoding: .utf8)) ?? ""
            throw Failure(message: detail.isEmpty ? "The Hold Calls shortcut could not run." : detail)
        }
        return try String(contentsOf: output, encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    struct Failure: LocalizedError {
        let message: String
        var errorDescription: String? { message }
    }
}
