import AppKit

/// Opens a new GitHub issue with the versions filled in. Nothing is sent until you submit it.
enum Feedback {
    static func open() {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "unknown"
        let build = info?["CFBundleVersion"] as? String ?? "unknown"
        let body = """
            **What happened?**


            **What did you expect?**


            ---
            Green Room \(version) (\(build))
            macOS \(ProcessInfo.processInfo.operatingSystemVersionString)
            """
        var components = URLComponents(string: "https://github.com/coreyhaines31/greenroom/issues/new")
        components?.queryItems = [URLQueryItem(name: "body", value: body)]
        if let url = components?.url { NSWorkspace.shared.open(url) }
    }
}
