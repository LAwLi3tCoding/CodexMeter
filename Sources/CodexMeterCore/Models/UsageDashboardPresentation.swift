import Foundation

public struct UsageMetricPresentation: Equatable, Sendable {
    public let label: String
    public let tokenText: String
    public let exactTokenText: String
    public let costText: String
    public let accessibilityLabel: String
}

public struct DailyUsagePresentation: Equatable, Sendable, Identifiable {
    public let id: String
    public let date: Date
    public let dateText: String
    public let tokens: Int64
    public let tokenText: String
    public let costText: String
    public let isToday: Bool
    public let accessibilityLabel: String
}

public struct UsageDashboardPresentation: Equatable, Sendable {
    public let metrics: [UsageMetricPresentation]
    public let days: [DailyUsagePresentation]
    public let currentModelText: String
    public let topModelText: String
    public let modelAttributionNote: String
    public let paceText: String
    public let paceSymbol: String
    public let chartCaption: String
    public let streakText: String?
    public let estimationNote: String
    public let updatedText: String

    public init(
        snapshot: UsageSnapshot,
        calendar: Calendar = .current
    ) {
        let today = calendar.startOfDay(for: snapshot.updatedAt)
        let periods: [(String, Int64, Double?)] = [
            (snapshot.primaryDayLabel, snapshot.todayTokens, snapshot.todayEstimatedCostUSD),
            ("7 DAYS", snapshot.sevenDayTokens, snapshot.sevenDayEstimatedCostUSD),
            ("30 DAYS", snapshot.thirtyDayTokens, snapshot.thirtyDayEstimatedCostUSD)
        ]
        metrics = periods.map { label, tokens, cost in
            let compactTokens = Self.compactTokenText(tokens)
            let exactTokens = Self.exactTokenText(tokens)
            let costText = Self.costText(cost)
            return UsageMetricPresentation(
                label: label,
                tokenText: compactTokens,
                exactTokenText: exactTokens,
                costText: costText,
                accessibilityLabel: "\(label), \(exactTokens) tokens, \(costText) estimated API cost"
            )
        }

        days = snapshot.days.map { day in
            let dateText = Self.dayText(day.date, calendar: calendar)
            return DailyUsagePresentation(
                id: day.dayID,
                date: day.date,
                dateText: dateText,
                tokens: day.tokens,
                tokenText: Self.exactTokenText(day.tokens),
                costText: Self.costText(day.estimatedCostUSD),
                isToday: calendar.isDate(day.date, inSameDayAs: today),
                accessibilityLabel: "\(dateText), \(Self.exactTokenText(day.tokens)) tokens, \(Self.costText(day.estimatedCostUSD)) estimated API cost"
            )
        }

        currentModelText = snapshot.currentModel ?? "Unavailable"
        if !snapshot.modelAttributionAvailable {
            topModelText = "Unavailable"
        } else if let topModel = snapshot.topModelSevenDays,
           let share = snapshot.topModelSevenDayShare {
            topModelText = "\(topModel) · \(Int((share * 100).rounded()))%"
        } else {
            topModelText = "Not enough recent threads"
        }
        modelAttributionNote = "By tokens in threads started in the last 7 days"

        let pace = Self.pacePresentation(snapshot.sevenDayChange)
        paceText = pace.text
        paceSymbol = pace.symbol

        let average = snapshot.thirtyDayTokens / Int64(max(snapshot.days.count, 1))
        let peakDay = snapshot.days.max { lhs, rhs in
            if lhs.tokens != rhs.tokens { return lhs.tokens < rhs.tokens }
            return lhs.date < rhs.date
        }
        let peakTokens = snapshot.peakDailyTokens ?? peakDay?.tokens ?? 0
        let peakDate = peakDay.map { Self.dayText($0.date, calendar: calendar) } ?? "—"
        chartCaption = "Avg \(Self.compactTokenText(average))/day · Peak \(peakDate), \(Self.compactTokenText(peakTokens))"

        if let streak = snapshot.currentStreakDays {
            streakText = "\(streak)-day streak"
        } else {
            streakText = nil
        }
        estimationNote = OpenAIStandardPricingCatalog.estimationNote
        updatedText = "Usage updated \(Self.clockText(snapshot.updatedAt, calendar: calendar))"
    }

    private static func compactTokenText(_ tokens: Int64) -> String {
        let value = max(0, tokens)
        switch value {
        case 1_000_000_000...:
            return scaledText(value, divisor: 1_000_000_000, suffix: "B")
        case 1_000_000...:
            return scaledText(value, divisor: 1_000_000, suffix: "M")
        case 1_000...:
            return scaledText(value, divisor: 1_000, suffix: "K")
        default:
            return String(value)
        }
    }

    private static func scaledText(
        _ value: Int64,
        divisor: Int64,
        suffix: String
    ) -> String {
        String(format: "%.2f%@", Double(value) / Double(divisor), suffix)
    }

    private static func exactTokenText(_ tokens: Int64) -> String {
        tokens.formatted(.number.grouping(.automatic))
    }

    private static func costText(_ cost: Double?) -> String {
        guard let cost else { return "—" }
        if cost > 0, cost < 0.01 { return "≈ < $0.01" }
        return String(format: "≈ $%.2f", cost)
    }

    private static func pacePresentation(
        _ change: Double?
    ) -> (text: String, symbol: String) {
        guard let change else {
            return ("Previous week unavailable", "minus")
        }
        let percentage = Int((abs(change) * 100).rounded())
        if change > 0 {
            return ("\(percentage)% more than previous 7 days", "arrow.up.right")
        }
        if change < 0 {
            return ("\(percentage)% less than previous 7 days", "arrow.down.right")
        }
        return ("Same as previous 7 days", "arrow.right")
    }

    private static func dayText(_ date: Date, calendar: Calendar) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "MMM d"
        return formatter.string(from: date)
    }

    private static func clockText(_ date: Date, calendar: Calendar) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
}
