import Foundation

enum CodexExecutableLocator {
    static func locate(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        fileManager: FileManager = .default
    ) -> URL? {
        var candidates: [String] = []

        if let override = environment["CODEX_BAR_CODEX_PATH"], !override.isEmpty {
            candidates.append(override)
        }

        if let path = environment["PATH"] {
            candidates.append(
                contentsOf: path
                    .split(separator: ":")
                    .map { String($0) + "/codex" }
            )
        }

        candidates.append(contentsOf: [
            "/Applications/ChatGPT.app/Contents/Resources/codex",
            "/opt/homebrew/bin/codex",
            "/usr/local/bin/codex",
            "/usr/bin/codex"
        ])

        for path in candidates where fileManager.isExecutableFile(atPath: path) {
            return URL(fileURLWithPath: path)
        }
        return nil
    }
}
