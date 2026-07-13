import Foundation

public enum QuotaFormatter {
    public static func windowLabel(minutes: Int?) -> String {
        guard let minutes else { return "额度" }

        if minutes == 10_080 {
            return "周额度"
        }

        if minutes >= 1_440, minutes.isMultiple(of: 1_440) {
            return "\(minutes / 1_440) 天额度"
        }

        if minutes >= 60, minutes.isMultiple(of: 60) {
            return "\(minutes / 60) 小时额度"
        }

        return "\(minutes) 分钟额度"
    }

    public static func countdown(until resetTime: Date?, now: Date = Date()) -> String {
        guard let resetTime else { return "—" }

        let remainingSeconds = Int(resetTime.timeIntervalSince(now))
        guard remainingSeconds > 0 else { return "即将重置" }

        let days = remainingSeconds / 86_400
        let hours = (remainingSeconds % 86_400) / 3_600
        let minutes = (remainingSeconds % 3_600) / 60

        if days > 0 {
            return "\(days)d\(hours)h\(minutes)m"
        }

        if hours > 0 {
            return "\(hours)h\(minutes)m"
        }

        return "\(max(1, (remainingSeconds + 59) / 60))m"
    }

    public static func maskedAccount(_ account: String?) -> String? {
        guard let account else { return nil }
        let parts = account.split(separator: "@", maxSplits: 1, omittingEmptySubsequences: false)
        guard parts.count == 2 else {
            return "\(account.prefix(3))***"
        }

        let visiblePrefix = parts[0].prefix(3)
        return "\(visiblePrefix)***@\(parts[1])"
    }

    public static func clock(for date: Date?, timeZone: TimeZone = .current) -> String {
        guard let date else { return "—" }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = timeZone
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
}
