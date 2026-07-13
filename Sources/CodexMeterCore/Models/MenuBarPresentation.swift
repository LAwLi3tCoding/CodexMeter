import Foundation

public struct MenuBarPresentation: Equatable, Sendable {
    public let brandText: String
    public let percentageText: String
    public let countdownText: String?
    public let labelText: String
    public let displayText: String
    public let accessibilityLabel: String
    public let systemImageName: String

    public init(quotas: [QuotaStatus], now: Date = Date()) {
        brandText = "Codex"
        systemImageName = "gauge.medium"

        guard let quota = quotas.min(by: Self.isMoreConstrained) else {
            percentageText = "--"
            countdownText = nil
            labelText = "--"
            displayText = "\(brandText) \(labelText)"
            accessibilityLabel = "Codex 额度暂不可用"
            return
        }

        let remaining = Int(quota.percentage.rounded())
        let countdown = quota.resetTime.map {
            QuotaFormatter.countdown(until: $0, now: now)
        }
        let percentage = "\(remaining)%"

        percentageText = percentage
        countdownText = countdown
        labelText = if let countdown {
            "\(percentage) · \(countdown)"
        } else {
            percentage
        }
        displayText = "\(brandText) \(labelText)"
        accessibilityLabel = if let countdown {
            "Codex 剩余 \(remaining)%，\(countdown) 后重置"
        } else {
            "Codex 剩余 \(remaining)%"
        }
    }

    private static func isMoreConstrained(_ lhs: QuotaStatus, _ rhs: QuotaStatus) -> Bool {
        if lhs.percentage != rhs.percentage {
            return lhs.percentage < rhs.percentage
        }

        return (lhs.resetTime ?? .distantFuture) < (rhs.resetTime ?? .distantFuture)
    }
}
