import Foundation

public enum QuotaLevel: Equatable, Sendable {
    case healthy
    case warning
    case critical
}

public struct QuotaCardPresentation: Equatable, Sendable {
    public let id: String
    public let title: String
    public let modelText: String
    public let percentageText: String
    public let remainingText: String
    public let usedText: String
    public let countdownText: String
    public let resetText: String
    public let progress: Double
    public let segmentFillAmounts: [Double]
    public let level: QuotaLevel
    public let accessibilityLabel: String

    public init(
        quota: QuotaStatus,
        now: Date = Date(),
        timeZone: TimeZone = .current
    ) {
        let remaining = Int(quota.percentage.rounded(.down))
        let used = 100 - remaining
        let normalizedProgress = min(max(quota.percentage / 100, 0), 1)
        let countdown = QuotaFormatter.countdown(
            until: quota.resetTime,
            now: now
        )
        let resetClock = QuotaFormatter.clock(
            for: quota.resetTime,
            timeZone: timeZone
        )

        id = quota.id
        title = quota.label
        modelText = quota.model
        percentageText = "\(remaining)%"
        remainingText = "剩余 \(remaining)%"
        usedText = "已用 \(used)%"
        countdownText = countdown
        resetText = "重置 \(resetClock)"
        progress = normalizedProgress
        segmentFillAmounts = (0..<10).map { index in
            min(max((normalizedProgress * 10) - Double(index), 0), 1)
        }
        level = Self.level(for: quota.percentage)
        accessibilityLabel = [
            quota.label,
            "模型 \(quota.model)",
            "剩余 \(remaining)%",
            "已用 \(used)%",
            quota.resetTime == nil ? nil : "距重置 \(countdown)",
            quota.resetTime == nil ? nil : "重置 \(resetClock)"
        ]
        .compactMap { $0 }
        .joined(separator: "，")
    }

    private static func level(for percentage: Double) -> QuotaLevel {
        switch percentage {
        case ..<20:
            return .critical
        case ..<50:
            return .warning
        default:
            return .healthy
        }
    }
}

public struct StatusPanelPresentation: Equatable, Sendable {
    public let accountText: String
    public let planText: String?
    public let modelText: String
    public let updatedText: String
    public let quotaCards: [QuotaCardPresentation]
    public let requiresQuotaOverflow: Bool

    public init(
        snapshot: ProviderSnapshot,
        now: Date = Date(),
        timeZone: TimeZone = .current
    ) {
        if let account = QuotaFormatter.maskedAccount(snapshot.account) {
            accountText = account
        } else {
            accountText = switch snapshot.accountKind {
            case .apiKey:
                "API key account"
            case .chatGPT:
                "ChatGPT account"
            case .unknown:
                "Codex 账号"
            }
        }
        planText = snapshot.plan?.uppercased()
        modelText = snapshot.model
        updatedText = "更新于 \(QuotaFormatter.clock(for: snapshot.updatedAt, timeZone: timeZone))"
        let cards = snapshot.quotas
            .sorted(by: Self.quotaDisplayOrder)
            .map {
                QuotaCardPresentation(
                    quota: $0,
                    now: now,
                    timeZone: timeZone
                )
            }
        quotaCards = cards
        requiresQuotaOverflow = cards.count > 4
    }

    private static func quotaDisplayOrder(
        _ lhs: QuotaStatus,
        _ rhs: QuotaStatus
    ) -> Bool {
        let lhsWindow = lhs.windowDurationMinutes ?? .max
        let rhsWindow = rhs.windowDurationMinutes ?? .max

        if lhsWindow != rhsWindow {
            return lhsWindow < rhsWindow
        }
        if lhs.limitID != rhs.limitID {
            return lhs.limitID < rhs.limitID
        }
        return lhs.id < rhs.id
    }
}
