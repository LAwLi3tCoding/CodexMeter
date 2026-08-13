import Foundation
import SQLite3
import CodexMeterCore

let usageDashboard: [HarnessTest] = [
    HarnessTest(
        suite: "usage-dashboard",
        name: "Usage protocol decodes summary and daily buckets",
        body: testUsageProtocolDecoding
    ),
    HarnessTest(
        suite: "usage-dashboard",
        name: "Usage dashboard produces exactly thirty local calendar days",
        body: testThirtyDayAggregation
    ),
    HarnessTest(
        suite: "usage-dashboard",
        name: "Missing current-day bucket falls back to the last completed day",
        body: testMissingTodayFallsBackToLastDay
    ),
    HarnessTest(
        suite: "usage-dashboard",
        name: "Missing daily buckets fail closed instead of displaying zero usage",
        body: testMissingDailyBuckets
    ),
    HarnessTest(
        suite: "usage-dashboard",
        name: "Config failure keeps token history and marks model and cost unavailable",
        body: testConfigFailureKeepsUsage
    ),
    HarnessTest(
        suite: "usage-dashboard",
        name: "Seven-day top model is ranked by token usage",
        body: testSevenDayTopModel
    ),
    HarnessTest(
        suite: "usage-dashboard",
        name: "USD estimates use observed model weights for each period",
        body: testObservedModelWeightedPricing
    ),
    HarnessTest(
        suite: "usage-dashboard",
        name: "Standard pricing produces an explicit blended estimate",
        body: testBlendedPricing
    ),
    HarnessTest(
        suite: "usage-dashboard",
        name: "Thread usage reader aggregates only model token metadata",
        body: testThreadUsageReader
    ),
    HarnessTest(
        suite: "usage-dashboard",
        name: "Model attribution failure stays distinct from empty recent history",
        body: testModelAttributionFailure
    ),
    HarnessTest(
        suite: "usage-dashboard",
        name: "Missing thread database reports model attribution unavailable",
        body: testUnavailableModelUsageReader
    ),
    HarnessTest(
        suite: "usage-dashboard",
        name: "Dashboard formats period totals and distinct model roles",
        body: testUsageDashboardPresentation
    ),
    HarnessTest(
        suite: "usage-dashboard",
        name: "Dashboard explains pace, peak, and estimate boundaries",
        body: testUsageDashboardInsights
    )
]

private func testUsageProtocolDecoding() throws {
    let data = Data(
        """
        {
          "summary": {
            "currentStreakDays": 4,
            "lifetimeTokens": 9000,
            "longestRunningTurnSec": 123,
            "longestStreakDays": 8,
            "peakDailyTokens": 3000
          },
          "dailyUsageBuckets": [
            {"startDate": "2026-01-29", "tokens": 1200},
            {"startDate": "2026-01-30", "tokens": 1800}
          ]
        }
        """.utf8
    )

    let response = try JSONDecoder().decode(CodexTokenUsageResponse.self, from: data)

    expectEqual(response.summary.currentStreakDays, 4)
    expectEqual(response.summary.lifetimeTokens, 9000)
    expectEqual(response.summary.longestRunningTurnSec, 123)
    expectEqual(response.summary.longestStreakDays, 8)
    expectEqual(response.summary.peakDailyTokens, 3000)
    expectEqual(
        response.dailyUsageBuckets,
        [
            CodexTokenUsageDailyBucket(startDate: "2026-01-29", tokens: 1200),
            CodexTokenUsageDailyBucket(startDate: "2026-01-30", tokens: 1800)
        ]
    )

    let nullData = Data(#"{"summary":{},"dailyUsageBuckets":null}"#.utf8)
    let nullResponse = try JSONDecoder().decode(CodexTokenUsageResponse.self, from: nullData)
    expectNil(nullResponse.dailyUsageBuckets)
}

private func testMissingDailyBuckets() async throws {
    let calendar = utcCalendar()
    let now = calendar.date(from: DateComponents(year: 2026, month: 1, day: 30, hour: 12))!
    let provider = CodexUsageProvider(
        client: StubUsageClient(
            response: CodexTokenUsageResponse(
                summary: CodexTokenUsageSummary(),
                dailyUsageBuckets: nil
            )
        ),
        modelUsageReader: StubModelUsageReader(records: []),
        now: { now },
        calendar: calendar
    )

    do {
        _ = try await provider.fetchUsage()
        TestRecorder.record("expected missing daily history to fail")
    } catch let error as CodexUsageProviderError {
        expectEqual(error, .dailyHistoryUnavailable)
    }
}

private func testConfigFailureKeepsUsage() async throws {
    let calendar = utcCalendar()
    let now = calendar.date(from: DateComponents(year: 2026, month: 1, day: 30, hour: 12))!
    let provider = CodexUsageProvider(
        client: StubUsageClient(
            response: CodexTokenUsageResponse(
                summary: CodexTokenUsageSummary(),
                dailyUsageBuckets: [
                    CodexTokenUsageDailyBucket(startDate: "2026-01-30", tokens: 1_000)
                ]
            ),
            configFails: true
        ),
        modelUsageReader: StubModelUsageReader(records: []),
        now: { now },
        calendar: calendar
    )

    let snapshot = try await provider.fetchUsage()
    let presentation = UsageDashboardPresentation(snapshot: snapshot, calendar: calendar)

    expectNil(snapshot.currentModel)
    expectNil(snapshot.todayEstimatedCostUSD)
    expectNil(snapshot.sevenDayEstimatedCostUSD)
    expectNil(snapshot.thirtyDayEstimatedCostUSD)
    expectEqual(presentation.currentModelText, "Unavailable")
}

private func testThirtyDayAggregation() async throws {
    let calendar = utcCalendar()
    let now = calendar.date(from: DateComponents(year: 2026, month: 1, day: 30, hour: 12))!
    let client = StubUsageClient(
        response: CodexTokenUsageResponse(
            summary: CodexTokenUsageSummary(currentStreakDays: 3, peakDailyTokens: 9_999),
            dailyUsageBuckets: [
                CodexTokenUsageDailyBucket(startDate: "2026-01-01", tokens: 100),
                CodexTokenUsageDailyBucket(startDate: "2026-01-24", tokens: 200),
                CodexTokenUsageDailyBucket(startDate: "2026-01-29", tokens: 300),
                CodexTokenUsageDailyBucket(startDate: "2026-01-30", tokens: 400)
            ]
        )
    )
    let provider = CodexUsageProvider(
        client: client,
        modelUsageReader: StubModelUsageReader(records: []),
        now: { now },
        calendar: calendar
    )

    let snapshot = try await provider.fetchUsage()

    expectEqual(snapshot.days.count, 30)
    expectEqual(snapshot.days.first?.dayID, "2026-01-01")
    expectEqual(snapshot.days.last?.dayID, "2026-01-30")
    expectEqual(snapshot.primaryDayLabel, "TODAY")
    expectEqual(snapshot.todayTokens, 400)
    expectEqual(snapshot.sevenDayTokens, 900)
    expectEqual(snapshot.thirtyDayTokens, 1000)
    expectEqual(snapshot.currentStreakDays, 3)
    expectEqual(snapshot.peakDailyTokens, 400)
}

private func testMissingTodayFallsBackToLastDay() async throws {
    let calendar = utcCalendar()
    let now = calendar.date(from: DateComponents(year: 2026, month: 1, day: 30, hour: 12))!
    let provider = CodexUsageProvider(
        client: StubUsageClient(
            response: CodexTokenUsageResponse(
                summary: CodexTokenUsageSummary(),
                dailyUsageBuckets: [
                    CodexTokenUsageDailyBucket(startDate: "2026-01-29", tokens: 725)
                ]
            )
        ),
        modelUsageReader: StubModelUsageReader(records: []),
        now: { now },
        calendar: calendar
    )

    let snapshot = try await provider.fetchUsage()
    let presentation = UsageDashboardPresentation(snapshot: snapshot, calendar: calendar)

    expectEqual(snapshot.primaryDayLabel, "LAST DAY")
    expectEqual(snapshot.todayTokens, 725)
    expectEqual(presentation.metrics.first?.label, "LAST DAY")
    expectEqual(presentation.metrics.first?.exactTokenText, "725")
}

private func testSevenDayTopModel() async throws {
    let calendar = utcCalendar()
    let now = calendar.date(from: DateComponents(year: 2026, month: 1, day: 30, hour: 12))!
    let client = StubUsageClient(
        response: CodexTokenUsageResponse(
            summary: CodexTokenUsageSummary(),
            dailyUsageBuckets: [
                CodexTokenUsageDailyBucket(startDate: "2026-01-30", tokens: 1000)
            ]
        ),
        model: "gpt-5.6-terra"
    )
    let records = [
        ModelTokenUsage(dayID: "2026-01-29", model: "gpt-5.6-sol", tokens: 600),
        ModelTokenUsage(dayID: "2026-01-30", model: "gpt-5.6-terra", tokens: 400),
        ModelTokenUsage(dayID: "2026-01-20", model: "gpt-5.6-luna", tokens: 900)
    ]
    let provider = CodexUsageProvider(
        client: client,
        modelUsageReader: StubModelUsageReader(records: records),
        now: { now },
        calendar: calendar
    )

    let snapshot = try await provider.fetchUsage()

    expectEqual(snapshot.currentModel, "gpt-5.6-terra")
    expectEqual(snapshot.topModelSevenDays, "gpt-5.6-sol")
    expectApproximately(snapshot.topModelSevenDayShare ?? 0, 0.6)
}

private func testObservedModelWeightedPricing() async throws {
    let calendar = utcCalendar()
    let now = calendar.date(from: DateComponents(year: 2026, month: 1, day: 30, hour: 12))!
    let provider = CodexUsageProvider(
        client: StubUsageClient(
            response: CodexTokenUsageResponse(
                summary: CodexTokenUsageSummary(),
                dailyUsageBuckets: [
                    CodexTokenUsageDailyBucket(startDate: "2026-01-20", tokens: 1_000_000),
                    CodexTokenUsageDailyBucket(startDate: "2026-01-29", tokens: 1_000_000),
                    CodexTokenUsageDailyBucket(startDate: "2026-01-30", tokens: 1_000_000)
                ]
            ),
            configFails: true
        ),
        modelUsageReader: StubModelUsageReader(records: [
            ModelTokenUsage(dayID: "2026-01-20", model: "gpt-5.6-luna", tokens: 100),
            ModelTokenUsage(dayID: "2026-01-29", model: "gpt-5.6-sol", tokens: 600),
            ModelTokenUsage(dayID: "2026-01-30", model: "gpt-5.6-terra", tokens: 400)
        ]),
        now: { now },
        calendar: calendar
    )

    let snapshot = try await provider.fetchUsage()

    expectNil(snapshot.currentModel)
    expectApproximately(snapshot.todayEstimatedCostUSD ?? 0, 0.57)
    expectApproximately(snapshot.sevenDayEstimatedCostUSD ?? 0, 2.166)
    expectApproximately(snapshot.thirtyDayEstimatedCostUSD ?? 0, 2.969_181_818)
    expectApproximately(
        snapshot.days.first { $0.dayID == "2026-01-20" }?.estimatedCostUSD ?? 0,
        0.057
    )
}

private func testBlendedPricing() {
    let catalog = OpenAIStandardPricingCatalog()

    expectApproximately(
        catalog.estimatedCostUSD(tokens: 1_000_000, model: "gpt-5.6-sol") ?? 0,
        1.425
    )
    expectApproximately(
        catalog.estimatedCostUSD(tokens: 1_000_000, model: "gpt-5.6-terra") ?? 0,
        0.57
    )
    expectApproximately(
        catalog.estimatedCostUSD(tokens: 1_000_000, model: "gpt-5.6-luna") ?? 0,
        0.057
    )
    expectApproximately(
        catalog.estimatedCostUSD(tokens: 1_000_000, model: "gpt-5.6") ?? 0,
        1.425
    )
    expectNil(catalog.estimatedCostUSD(tokens: 1_000_000, model: "unknown-model"))
}

private func testThreadUsageReader() async throws {
    let fileURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("CodexMeterUsage-\(UUID().uuidString).sqlite")
    defer { try? FileManager.default.removeItem(at: fileURL) }

    var database: OpaquePointer?
    guard sqlite3_open(fileURL.path, &database) == SQLITE_OK else {
        throw TestDatabaseError.openFailed
    }
    defer { sqlite3_close(database) }

    try execute(
        database,
        """
        CREATE TABLE threads (
            id TEXT PRIMARY KEY,
            created_at INTEGER NOT NULL,
            created_at_ms INTEGER,
            updated_at INTEGER NOT NULL,
            updated_at_ms INTEGER,
            model TEXT,
            tokens_used INTEGER NOT NULL DEFAULT 0
        );
        INSERT INTO threads VALUES ('a', 1769731200, 1769731200000, 1769731200, 1769731200000, 'gpt-5.6-sol', 100);
        INSERT INTO threads VALUES ('b', 1769731200, 1769731200000, 1769731200, 1769731200000, 'gpt-5.6-sol', 250);
        INSERT INTO threads VALUES ('c', 1769644800, 1769644800000, 1769644800, 1769644800000, 'gpt-5.6-terra', 400);
        INSERT INTO threads VALUES ('d', 1769644800, 1769644800000, 1769644800, 1769644800000, NULL, 900);
        INSERT INTO threads VALUES ('old', 1768000000, 1768000000000, 1769731200, 1769731200000, 'gpt-5.6-luna', 9999);
        """
    )

    let reader = SQLiteThreadModelUsageReader(databaseURL: fileURL)
    let records = try await reader.readModelUsage(since: Date(timeIntervalSince1970: 1_769_644_800))

    expectEqual(
        records,
        [
            ModelTokenUsage(dayID: "2026-01-29", model: "gpt-5.6-terra", tokens: 400),
            ModelTokenUsage(dayID: "2026-01-30", model: "gpt-5.6-sol", tokens: 350)
        ]
    )
}

private func testModelAttributionFailure() async throws {
    let calendar = utcCalendar()
    let now = calendar.date(from: DateComponents(year: 2026, month: 1, day: 30, hour: 12))!
    let provider = CodexUsageProvider(
        client: StubUsageClient(
            response: CodexTokenUsageResponse(
                summary: CodexTokenUsageSummary(),
                dailyUsageBuckets: [
                    CodexTokenUsageDailyBucket(startDate: "2026-01-30", tokens: 100)
                ]
            )
        ),
        modelUsageReader: FailingModelUsageReader(),
        now: { now },
        calendar: calendar
    )

    let snapshot = try await provider.fetchUsage()
    let presentation = UsageDashboardPresentation(snapshot: snapshot, calendar: calendar)

    expectEqual(snapshot.modelAttributionAvailable, false)
    expectNil(snapshot.todayEstimatedCostUSD)
    expectNil(snapshot.sevenDayEstimatedCostUSD)
    expectNil(snapshot.thirtyDayEstimatedCostUSD)
    expectEqual(presentation.topModelText, "Unavailable")
}

private func testUnavailableModelUsageReader() async {
    do {
        _ = try await UnavailableModelUsageReader().readModelUsage(since: Date())
        TestRecorder.record("expected missing model database to fail")
    } catch let error as SQLiteThreadModelUsageReaderError {
        expectEqual(error, .databaseUnavailable)
    } catch {
        TestRecorder.record("expected databaseUnavailable, got \(error)")
    }
}

private func testUsageDashboardPresentation() {
    let calendar = utcCalendar()
    let now = calendar.date(from: DateComponents(year: 2026, month: 1, day: 30, hour: 12))!
    let snapshot = makePresentationUsageSnapshot(now: now, calendar: calendar)

    let presentation = UsageDashboardPresentation(
        snapshot: snapshot,
        calendar: calendar
    )

    expectEqual(presentation.metrics.map(\.label), ["TODAY", "7 DAYS", "30 DAYS"])
    expectEqual(presentation.metrics.map(\.tokenText), ["100", "700", "1.00K"])
    expectEqual(presentation.metrics.map(\.costText), ["≈ $0.01", "≈ $0.07", "≈ $0.10"])
    expectEqual(presentation.currentModelText, "gpt-5.6-terra")
    expectEqual(presentation.topModelText, "gpt-5.6-sol · 60%")
    expectEqual(presentation.days.count, 30)
    expectEqual(presentation.days.last?.isToday, true)
}

private func testUsageDashboardInsights() {
    let calendar = utcCalendar()
    let now = calendar.date(from: DateComponents(year: 2026, month: 1, day: 30, hour: 12))!
    let presentation = UsageDashboardPresentation(
        snapshot: makePresentationUsageSnapshot(now: now, calendar: calendar),
        calendar: calendar
    )

    expectEqual(presentation.paceText, "18% more than previous 7 days")
    expectEqual(presentation.paceSymbol, "arrow.up.right")
    expectEqual(presentation.chartCaption, "Avg 33/day · Peak Jan 30, 100")
    expectEqual(presentation.streakText, "4-day streak")
    expectEqual(presentation.estimationNote, OpenAIStandardPricingCatalog.estimationNote)
}

private actor StubUsageClient: CodexClientProtocol {
    let response: CodexTokenUsageResponse
    let model: String
    let configFails: Bool

    init(
        response: CodexTokenUsageResponse,
        model: String = "gpt-5.6-sol",
        configFails: Bool = false
    ) {
        self.response = response
        self.model = model
        self.configFails = configFails
    }

    func account() async throws -> CodexAccountResponse {
        CodexAccountResponse(account: nil, requiresOpenaiAuth: false)
    }

    func rateLimits() async throws -> CodexRateLimitsResponse { .empty }

    func effectiveConfig() async throws -> CodexConfigResponse {
        if configFails { throw StubUsageClientError.configUnavailable }
        return CodexConfigResponse(config: CodexEffectiveConfig(model: model))
    }

    func tokenUsage() async throws -> CodexTokenUsageResponse { response }
}

private enum StubUsageClientError: Error {
    case configUnavailable
}

private struct StubModelUsageReader: ModelUsageReading {
    let records: [ModelTokenUsage]

    func readModelUsage(since: Date) async throws -> [ModelTokenUsage] {
        records
    }
}

private struct FailingModelUsageReader: ModelUsageReading {
    func readModelUsage(since: Date) async throws -> [ModelTokenUsage] {
        throw SQLiteThreadModelUsageReaderError.queryFailed
    }
}

private enum TestDatabaseError: Error {
    case openFailed
    case statementFailed
}

private func execute(_ database: OpaquePointer?, _ sql: String) throws {
    guard sqlite3_exec(database, sql, nil, nil, nil) == SQLITE_OK else {
        throw TestDatabaseError.statementFailed
    }
}

private func utcCalendar() -> Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0)!
    return calendar
}

private func makePresentationUsageSnapshot(
    now: Date,
    calendar: Calendar
) -> UsageSnapshot {
    let start = calendar.date(byAdding: .day, value: -29, to: calendar.startOfDay(for: now))!
    let formatter = DateFormatter()
    formatter.calendar = calendar
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = calendar.timeZone
    formatter.dateFormat = "yyyy-MM-dd"
    let days = (0..<30).map { offset -> UsageDay in
        let date = calendar.date(byAdding: .day, value: offset, to: start)!
        return UsageDay(
            dayID: formatter.string(from: date),
            date: date,
            tokens: offset == 29 ? 100 : 0,
            estimatedCostUSD: offset == 29 ? 0.01 : 0
        )
    }
    return UsageSnapshot(
        days: days,
        todayTokens: 100,
        sevenDayTokens: 700,
        thirtyDayTokens: 1_000,
        todayEstimatedCostUSD: 0.01,
        sevenDayEstimatedCostUSD: 0.07,
        thirtyDayEstimatedCostUSD: 0.10,
        currentModel: "gpt-5.6-terra",
        topModelSevenDays: "gpt-5.6-sol",
        topModelSevenDayShare: 0.6,
        currentStreakDays: 4,
        peakDailyTokens: 100,
        sevenDayChange: 0.18,
        updatedAt: now
    )
}
