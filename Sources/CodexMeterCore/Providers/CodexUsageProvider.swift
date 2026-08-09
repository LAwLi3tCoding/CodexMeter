import Foundation

public protocol UsageProviding: Sendable {
    func fetchUsage() async throws -> UsageSnapshot
    func shutdown() async
}

public extension UsageProviding {
    func shutdown() async {}
}

public enum CodexUsageProviderError: Error, Equatable, Sendable {
    case dailyHistoryUnavailable
}

public struct CodexUsageProvider: UsageProviding, Sendable {
    private let client: any CodexClientProtocol
    private let modelUsageReader: any ModelUsageReading
    private let pricing: OpenAIStandardPricingCatalog
    private let now: @Sendable () -> Date
    private let calendar: Calendar

    public init(
        client: any CodexClientProtocol,
        modelUsageReader: any ModelUsageReading,
        pricing: OpenAIStandardPricingCatalog = OpenAIStandardPricingCatalog(),
        now: @escaping @Sendable () -> Date = { Date() },
        calendar: Calendar = .current
    ) {
        self.client = client
        self.modelUsageReader = modelUsageReader
        self.pricing = pricing
        self.now = now
        self.calendar = calendar
    }

    public func fetchUsage() async throws -> UsageSnapshot {
        let updatedAt = now()
        let today = calendar.startOfDay(for: updatedAt)
        let startDay = calendar.date(byAdding: .day, value: -29, to: today) ?? today

        async let responseRequest = client.tokenUsage()
        async let configRequest = try? client.effectiveConfig()
        async let modelUsageRequest = readModelUsage(since: startDay)
        let response = try await responseRequest
        let currentModel = await configRequest?.config.model.flatMap { model in
            let normalized = model.trimmingCharacters(in: .whitespacesAndNewlines)
            return normalized.isEmpty ? nil : normalized
        }
        let modelUsageResult = await modelUsageRequest
        let modelUsage = modelUsageResult.records

        guard let dailyUsageBuckets = response.dailyUsageBuckets else {
            throw CodexUsageProviderError.dailyHistoryUnavailable
        }

        let apiTokensByDay = Dictionary(
            dailyUsageBuckets.map { ($0.startDate, max(0, $0.tokens)) },
            uniquingKeysWith: +
        )
        let formatter = dayFormatter()

        let days = (0..<30).compactMap { offset -> UsageDay? in
            guard let day = calendar.date(byAdding: .day, value: offset, to: startDay) else {
                return nil
            }
            let dayID = formatter.string(from: day)
            let tokens = apiTokensByDay[dayID] ?? 0
            return UsageDay(
                dayID: dayID,
                date: day,
                tokens: tokens,
                estimatedCostUSD: currentModel.flatMap { model in
                    pricing.estimatedCostUSD(tokens: tokens, model: model)
                }
            )
        }

        let sevenDays = Array(days.suffix(7))
        let previousSevenDays = Array(days.dropLast(7).suffix(7))
        let todayDayID = formatter.string(from: today)
        let hasTodayBucket = apiTokensByDay[todayDayID] != nil
        let primaryDayUsage = hasTodayBucket ? days.last : days.dropLast().last
        let sevenDayIDs = Set(sevenDays.map(\.dayID))
        let sevenDayModelUsage = modelUsage.filter {
            sevenDayIDs.contains($0.dayID)
        }
        let topModel = topModel(in: sevenDayModelUsage)
        let sevenDayTokens = tokenTotal(sevenDays)
        let previousSevenDayTokens = tokenTotal(previousSevenDays)

        return UsageSnapshot(
            days: days,
            primaryDayLabel: hasTodayBucket ? "TODAY" : "LAST DAY",
            todayTokens: primaryDayUsage?.tokens ?? 0,
            sevenDayTokens: sevenDayTokens,
            thirtyDayTokens: tokenTotal(days),
            todayEstimatedCostUSD: primaryDayUsage?.estimatedCostUSD,
            sevenDayEstimatedCostUSD: estimatedCostTotal(sevenDays),
            thirtyDayEstimatedCostUSD: estimatedCostTotal(days),
            currentModel: currentModel,
            topModelSevenDays: topModel?.model,
            topModelSevenDayShare: topModel?.share,
            modelAttributionAvailable: modelUsageResult.available,
            currentStreakDays: response.summary.currentStreakDays,
            peakDailyTokens: days.map(\.tokens).max(),
            sevenDayChange: change(
                current: sevenDayTokens,
                previous: previousSevenDayTokens
            ),
            updatedAt: updatedAt
        )
    }

    public func shutdown() async {
        await client.shutdown()
    }

    private func readModelUsage(
        since: Date
    ) async -> (records: [ModelTokenUsage], available: Bool) {
        do {
            return (try await modelUsageReader.readModelUsage(since: since), true)
        } catch {
            return ([], false)
        }
    }

    private func topModel(
        in usage: [ModelTokenUsage]
    ) -> (model: String, share: Double)? {
        let totals = Dictionary(grouping: usage, by: \.model)
            .mapValues { records in records.reduce(Int64(0)) { $0 + $1.tokens } }
        let overall = totals.values.reduce(Int64(0), +)
        guard overall > 0,
              let top = totals.sorted(by: {
                  $0.value == $1.value ? $0.key < $1.key : $0.value > $1.value
              }).first else {
            return nil
        }
        return (top.key, Double(top.value) / Double(overall))
    }

    private func tokenTotal(_ days: [UsageDay]) -> Int64 {
        days.reduce(Int64(0)) { $0 + $1.tokens }
    }

    private func estimatedCostTotal(_ days: [UsageDay]) -> Double? {
        guard !days.contains(where: { $0.tokens > 0 && $0.estimatedCostUSD == nil }) else {
            return nil
        }
        return days.compactMap(\.estimatedCostUSD).reduce(0, +)
    }

    private func change(current: Int64, previous: Int64) -> Double? {
        guard previous > 0 else { return nil }
        return Double(current - previous) / Double(previous)
    }

    private func dayFormatter() -> DateFormatter {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }
}
