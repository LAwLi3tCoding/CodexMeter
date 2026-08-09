import Foundation
import SQLite3

public struct ModelTokenUsage: Equatable, Sendable {
    public let dayID: String
    public let model: String
    public let tokens: Int64

    public init(dayID: String, model: String, tokens: Int64) {
        self.dayID = dayID
        self.model = model
        self.tokens = tokens
    }
}

public protocol ModelUsageReading: Sendable {
    func readModelUsage(since: Date) async throws -> [ModelTokenUsage]
}

public enum SQLiteThreadModelUsageReaderError: Error, Equatable, Sendable {
    case databaseUnavailable
    case queryFailed
}

public struct SQLiteThreadModelUsageReader: ModelUsageReading, Sendable {
    public let databaseURL: URL

    public init(databaseURL: URL) {
        self.databaseURL = databaseURL
    }

    public static func defaultDatabaseURL(
        fileManager: FileManager = .default,
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> URL? {
        let homeURL: URL
        if let configuredHome = environment["CODEX_HOME"], !configuredHome.isEmpty {
            homeURL = URL(fileURLWithPath: configuredHome, isDirectory: true)
        } else {
            homeURL = fileManager.homeDirectoryForCurrentUser
                .appendingPathComponent(".codex", isDirectory: true)
        }

        let candidates = [
            homeURL.appendingPathComponent("state_5.sqlite"),
            homeURL.appendingPathComponent("sqlite/state_5.sqlite")
        ]
        return candidates.first { fileManager.isReadableFile(atPath: $0.path) }
    }

    public func readModelUsage(since: Date) async throws -> [ModelTokenUsage] {
        var database: OpaquePointer?
        guard sqlite3_open_v2(
            databaseURL.path,
            &database,
            SQLITE_OPEN_READONLY | SQLITE_OPEN_NOMUTEX,
            nil
        ) == SQLITE_OK else {
            sqlite3_close(database)
            throw SQLiteThreadModelUsageReaderError.databaseUnavailable
        }
        defer { sqlite3_close(database) }

        let sql = """
        SELECT
            strftime(
                '%Y-%m-%d',
                COALESCE(created_at_ms, created_at * 1000) / 1000,
                'unixepoch',
                'localtime'
            ) AS usage_day,
            TRIM(model) AS usage_model,
            SUM(tokens_used) AS token_total
        FROM threads
        WHERE (
            created_at_ms >= ?
            OR (created_at_ms IS NULL AND created_at >= ?)
        )
          AND model IS NOT NULL
          AND TRIM(model) <> ''
          AND tokens_used > 0
        GROUP BY usage_day, usage_model
        ORDER BY usage_day, usage_model
        """

        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK else {
            throw SQLiteThreadModelUsageReaderError.queryFailed
        }
        defer { sqlite3_finalize(statement) }

        let sinceMilliseconds = Int64(since.timeIntervalSince1970 * 1_000)
        let sinceSeconds = Int64(since.timeIntervalSince1970)
        guard sqlite3_bind_int64(statement, 1, sinceMilliseconds) == SQLITE_OK,
              sqlite3_bind_int64(statement, 2, sinceSeconds) == SQLITE_OK else {
            throw SQLiteThreadModelUsageReaderError.queryFailed
        }

        var records: [ModelTokenUsage] = []
        while true {
            switch sqlite3_step(statement) {
            case SQLITE_ROW:
                guard let dayCString = sqlite3_column_text(statement, 0),
                      let modelCString = sqlite3_column_text(statement, 1) else {
                    continue
                }
                records.append(
                    ModelTokenUsage(
                        dayID: String(cString: dayCString),
                        model: String(cString: modelCString),
                        tokens: sqlite3_column_int64(statement, 2)
                    )
                )
            case SQLITE_DONE:
                return records
            default:
                throw SQLiteThreadModelUsageReaderError.queryFailed
            }
        }
    }
}

public struct UnavailableModelUsageReader: ModelUsageReading, Sendable {
    public init() {}

    public func readModelUsage(since: Date) async throws -> [ModelTokenUsage] {
        throw SQLiteThreadModelUsageReaderError.databaseUnavailable
    }
}
