import Foundation
import Darwin

public final class WidgetSnapshotStore: @unchecked Sendable {
    private enum Backend {
        case defaults(UserDefaults)
        case file(URL, FileManager)
    }

    private let backend: Backend

    public init(defaults: UserDefaults) {
        backend = .defaults(defaults)
    }

    public init(fileURL: URL, fileManager: FileManager = .default) {
        backend = .file(fileURL, fileManager)
    }

    public static func sharedApplicationSupport(
        fileManager: FileManager = .default
    ) -> WidgetSnapshotStore? {
        guard let homeDirectoryURL = realHomeDirectoryURL() else {
            return nil
        }
        return applicationSupport(
            homeDirectoryURL: homeDirectoryURL,
            fileManager: fileManager
        )
    }

    public static func applicationSupport(
        homeDirectoryURL: URL,
        fileManager: FileManager = .default
    ) -> WidgetSnapshotStore {
        let fileURL = homeDirectoryURL
            .appendingPathComponent("Library", isDirectory: true)
            .appendingPathComponent("Application Support", isDirectory: true)
            .appendingPathComponent("CodexMeter", isDirectory: true)
            .appendingPathComponent(WidgetConfiguration.snapshotFileName)
        return WidgetSnapshotStore(fileURL: fileURL, fileManager: fileManager)
    }

    public func read() -> WidgetQuotaSnapshot? {
        guard
            let data = readData(),
            let snapshot = try? Self.decoder.decode(WidgetQuotaSnapshot.self, from: data),
            snapshot.schemaVersion == WidgetQuotaSnapshot.currentSchemaVersion
        else {
            return nil
        }

        return snapshot
    }

    public func write(_ snapshot: WidgetQuotaSnapshot) throws {
        let data = try Self.encoder.encode(snapshot)
        switch backend {
        case let .defaults(defaults):
            defaults.set(data, forKey: WidgetConfiguration.snapshotKey)
        case let .file(fileURL, fileManager):
            let directoryURL = fileURL.deletingLastPathComponent()
            try fileManager.createDirectory(
                at: directoryURL,
                withIntermediateDirectories: true,
                attributes: [.posixPermissions: 0o700]
            )
            try fileManager.setAttributes(
                [.posixPermissions: 0o700],
                ofItemAtPath: directoryURL.path
            )
            try writeAtomically(
                data,
                to: fileURL,
                fileManager: fileManager
            )
        }
    }

    private func readData() -> Data? {
        switch backend {
        case let .defaults(defaults):
            defaults.data(forKey: WidgetConfiguration.snapshotKey)
        case let .file(fileURL, _):
            try? Data(contentsOf: fileURL)
        }
    }

    private static var encoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .millisecondsSince1970
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }

    private static var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .millisecondsSince1970
        return decoder
    }

    private func writeAtomically(
        _ data: Data,
        to fileURL: URL,
        fileManager: FileManager
    ) throws {
        let temporaryURL = fileURL.deletingLastPathComponent()
            .appendingPathComponent(".\(fileURL.lastPathComponent).\(UUID().uuidString).tmp")
        defer { try? fileManager.removeItem(at: temporaryURL) }

        try data.write(to: temporaryURL, options: .atomic)
        try fileManager.setAttributes(
            [.posixPermissions: 0o600],
            ofItemAtPath: temporaryURL.path
        )

        if fileManager.fileExists(atPath: fileURL.path) {
            _ = try fileManager.replaceItemAt(
                fileURL,
                withItemAt: temporaryURL,
                backupItemName: nil,
                options: [.usingNewMetadataOnly]
            )
        } else {
            try fileManager.moveItem(at: temporaryURL, to: fileURL)
        }
    }

    private static func realHomeDirectoryURL() -> URL? {
        let suggestedSize = sysconf(_SC_GETPW_R_SIZE_MAX)
        var bufferSize = suggestedSize > 0 ? Int(suggestedSize) : 16_384

        for _ in 0..<3 {
            var passwordEntry = passwd()
            var result: UnsafeMutablePointer<passwd>?
            var buffer = [CChar](repeating: 0, count: bufferSize)
            let status = buffer.withUnsafeMutableBufferPointer { pointer in
                getpwuid_r(
                    getuid(),
                    &passwordEntry,
                    pointer.baseAddress,
                    pointer.count,
                    &result
                )
            }

            if status == ERANGE {
                bufferSize *= 2
                continue
            }

            guard
                status == 0,
                result != nil,
                let directory = passwordEntry.pw_dir
            else {
                return nil
            }
            return URL(
                fileURLWithPath: String(cString: directory),
                isDirectory: true
            )
        }

        return nil
    }
}
