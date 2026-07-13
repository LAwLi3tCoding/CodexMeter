import Foundation

public struct QuotaStatus: Identifiable, Equatable, Sendable {
    public let id: String
    public let provider: ProviderKind
    public let account: String?
    public let model: String
    public let limitID: String
    public let label: String
    public let used: Double
    public let remaining: Double
    public let percentage: Double
    public let resetTime: Date?
    public let windowDurationMinutes: Int?
    public let updatedAt: Date

    public init(
        id: String,
        provider: ProviderKind,
        account: String?,
        model: String,
        limitID: String,
        label: String,
        usedPercent: Double,
        resetTime: Date?,
        windowDurationMinutes: Int?,
        updatedAt: Date
    ) {
        let clampedUsed = min(max(usedPercent, 0), 100)
        let remaining = 100 - clampedUsed

        self.id = id
        self.provider = provider
        self.account = account
        self.model = model
        self.limitID = limitID
        self.label = label
        self.used = clampedUsed
        self.remaining = remaining
        self.percentage = remaining
        self.resetTime = resetTime
        self.windowDurationMinutes = windowDurationMinutes
        self.updatedAt = updatedAt
    }
}
