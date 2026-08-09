import Foundation

public enum QuotaLevel: Equatable, Sendable {
    case healthy
    case warning
    case critical
}

public enum QuotaCardDisplayStyle: Equatable, Sendable {
    case standard
    case compact
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
    public let displayStyle: QuotaCardDisplayStyle
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
        remainingText = "\(remaining)% remaining"
        usedText = "\(used)% used"
        countdownText = countdown
        resetText = "Resets at \(resetClock)"
        progress = normalizedProgress
        segmentFillAmounts = (0..<10).map { index in
            min(max((normalizedProgress * 10) - Double(index), 0), 1)
        }
        level = Self.level(for: quota.percentage)
        displayStyle = (quota.windowDurationMinutes ?? 0) >= 10_080
            ? .compact
            : .standard
        accessibilityLabel = [
            quota.label,
            "model \(quota.model)",
            "\(remaining)% remaining",
            "\(used)% used",
            quota.resetTime == nil ? nil : "resets in \(countdown)",
            quota.resetTime == nil ? nil : "resets at \(resetClock)"
        ]
        .compactMap { $0 }
        .joined(separator: ", ")
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
                "Codex account"
            }
        }
        planText = Self.planDisplayText(
            for: snapshot.plan,
            provider: snapshot.provider
        )
        modelText = snapshot.model
        updatedText = "Updated at \(QuotaFormatter.clock(for: snapshot.updatedAt, timeZone: timeZone))"
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

    private static func planDisplayText(
        for plan: String?,
        provider: ProviderKind
    ) -> String? {
        guard let plan else { return nil }
        let normalized = plan.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return nil }

        return switch (provider, normalized.lowercased()) {
        case (.codex, "pro"):
            "PRO 20X"
        default:
            normalized.uppercased()
        }
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
