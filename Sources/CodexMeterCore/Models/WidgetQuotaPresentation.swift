import Foundation

public struct WidgetQuotaItemPresentation: Equatable, Sendable {
    public let id: String
    public let label: String
    public let percentageText: String
    public let countdownText: String
    public let segmentFillAmounts: [Double]
    public let level: QuotaLevel

    init(quota: WidgetQuotaItem, now: Date) {
        let remainingPercent = min(max(quota.remainingPercent, 0), 100)
        let progress = remainingPercent / 100

        id = quota.id
        label = quota.label
        percentageText = "\(Int(remainingPercent.rounded(.down)))%"
        countdownText = QuotaFormatter.countdown(
            until: quota.resetTime,
            now: now
        )
        segmentFillAmounts = (0..<10).map { index in
            min(max((progress * 10) - Double(index), 0), 1)
        }
        level = Self.level(for: remainingPercent)
    }

    private static func level(for remainingPercent: Double) -> QuotaLevel {
        switch remainingPercent {
        case ..<20:
            return .critical
        case ..<50:
            return .warning
        default:
            return .healthy
        }
    }
}

public struct WidgetQuotaPresentation: Equatable, Sendable {
    public let modelText: String
    public let updatedText: String
    public let isStale: Bool
    public let quotas: [WidgetQuotaItemPresentation]

    public init(snapshot: WidgetQuotaSnapshot, now: Date = Date()) {
        modelText = snapshot.model
        updatedText = "更新于 \(QuotaFormatter.clock(for: snapshot.updatedAt))"
        isStale = now.timeIntervalSince(snapshot.updatedAt) >= 15 * 60
        quotas = snapshot.quotas
            .sorted(by: Self.isMoreConstrained)
            .map { WidgetQuotaItemPresentation(quota: $0, now: now) }
    }

    private static func isMoreConstrained(
        _ lhs: WidgetQuotaItem,
        _ rhs: WidgetQuotaItem
    ) -> Bool {
        if lhs.remainingPercent != rhs.remainingPercent {
            return lhs.remainingPercent < rhs.remainingPercent
        }

        let lhsResetTime = lhs.resetTime ?? .distantFuture
        let rhsResetTime = rhs.resetTime ?? .distantFuture
        if lhsResetTime != rhsResetTime {
            return lhsResetTime < rhsResetTime
        }

        return lhs.id < rhs.id
    }
}
