import Foundation

public enum CodexExecutableLocatorError: Error, Equatable, Sendable {
    case notFound
}

public struct CodexExecutableLocator: Sendable {
    private let candidatePaths: [String]

    public init(candidatePaths: [String]? = nil) {
        self.candidatePaths = candidatePaths ?? Self.defaultCandidatePaths()
    }

    public func locate() throws -> URL {
        for path in candidatePaths {
            let expandedPath = NSString(string: path).expandingTildeInPath
            var isDirectory: ObjCBool = false
            guard FileManager.default.fileExists(atPath: expandedPath, isDirectory: &isDirectory),
                  !isDirectory.boolValue,
                  FileManager.default.isExecutableFile(atPath: expandedPath) else {
                continue
            }

            return URL(fileURLWithPath: expandedPath)
        }

        throw CodexExecutableLocatorError.notFound
    }

    private static func defaultCandidatePaths() -> [String] {
        let pathCandidates = ProcessInfo.processInfo.environment["PATH"]?
            .split(separator: ":")
            .map { "\($0)/codex" } ?? []

        return pathCandidates + [
            "/opt/homebrew/bin/codex",
            "/usr/local/bin/codex",
            "~/.local/bin/codex",
            "~/.volta/bin/codex"
        ]
    }
}
