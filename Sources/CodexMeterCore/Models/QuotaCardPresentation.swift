import Foundation

public enum QuotaLevel: Equatable, Sendable {
    case healthy
    case warning
    case low
    case critical
}

public struct QuotaCardPresentation: Equatable, Sendable {
    public let id: String
    public let title: String
    public let modelText: String
    public let percentageText: String
    public let remainingText: String
    public let countdownText: String
    public let resetText: String
    public let progress: Double
    public let level: QuotaLevel
    public let accessibilityLabel: String

    public init(
        quota: QuotaStatus,
        now: Date = Date(),
        timeZone: TimeZone = .current
    ) {
        let remaining = Int(quota.percentage.rounded())
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
        countdownText = countdown
        resetText = "重置 \(resetClock)"
        progress = quota.percentage / 100
        level = Self.level(for: quota.percentage)
        accessibilityLabel = [
            quota.label,
            "模型 \(quota.model)",
            "剩余 \(remaining)%",
            quota.resetTime == nil ? nil : "距重置 \(countdown)",
            quota.resetTime == nil ? nil : "重置 \(resetClock)"
        ]
        .compactMap { $0 }
        .joined(separator: "，")
    }

    private static func level(for percentage: Double) -> QuotaLevel {
        switch percentage {
        case ...10:
            return .critical
        case ...30:
            return .low
        case ...50:
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

    public init(snapshot: ProviderSnapshot, timeZone: TimeZone = .current) {
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
    }
}
