import Foundation

public struct UsageDay: Equatable, Sendable, Identifiable {
    public let dayID: String
    public let date: Date
    public let tokens: Int64
    public let estimatedCostUSD: Double?

    public var id: String { dayID }

    public init(
        dayID: String,
        date: Date,
        tokens: Int64,
        estimatedCostUSD: Double?
    ) {
        self.dayID = dayID
        self.date = date
        self.tokens = tokens
        self.estimatedCostUSD = estimatedCostUSD
    }
}

public struct UsageSnapshot: Equatable, Sendable {
    public let days: [UsageDay]
    public let primaryDayLabel: String
    public let todayTokens: Int64
    public let sevenDayTokens: Int64
    public let thirtyDayTokens: Int64
    public let todayEstimatedCostUSD: Double?
    public let sevenDayEstimatedCostUSD: Double?
    public let thirtyDayEstimatedCostUSD: Double?
    public let currentModel: String?
    public let topModelSevenDays: String?
    public let topModelSevenDayShare: Double?
    public let modelAttributionAvailable: Bool
    public let currentStreakDays: Int64?
    public let peakDailyTokens: Int64?
    public let sevenDayChange: Double?
    public let updatedAt: Date

    public init(
        days: [UsageDay],
        primaryDayLabel: String = "TODAY",
        todayTokens: Int64,
        sevenDayTokens: Int64,
        thirtyDayTokens: Int64,
        todayEstimatedCostUSD: Double?,
        sevenDayEstimatedCostUSD: Double?,
        thirtyDayEstimatedCostUSD: Double?,
        currentModel: String?,
        topModelSevenDays: String?,
        topModelSevenDayShare: Double?,
        modelAttributionAvailable: Bool = true,
        currentStreakDays: Int64?,
        peakDailyTokens: Int64?,
        sevenDayChange: Double?,
        updatedAt: Date
    ) {
        self.days = days
        self.primaryDayLabel = primaryDayLabel
        self.todayTokens = todayTokens
        self.sevenDayTokens = sevenDayTokens
        self.thirtyDayTokens = thirtyDayTokens
        self.todayEstimatedCostUSD = todayEstimatedCostUSD
        self.sevenDayEstimatedCostUSD = sevenDayEstimatedCostUSD
        self.thirtyDayEstimatedCostUSD = thirtyDayEstimatedCostUSD
        self.currentModel = currentModel
        self.topModelSevenDays = topModelSevenDays
        self.topModelSevenDayShare = topModelSevenDayShare
        self.modelAttributionAvailable = modelAttributionAvailable
        self.currentStreakDays = currentStreakDays
        self.peakDailyTokens = peakDailyTokens
        self.sevenDayChange = sevenDayChange
        self.updatedAt = updatedAt
    }
}
