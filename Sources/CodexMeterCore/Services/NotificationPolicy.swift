import Foundation

public struct NotificationDecision: Equatable, Sendable {
    public let threshold: Int
    public let remainingPercentage: Int

    public init(threshold: Int, remainingPercentage: Int) {
        self.threshold = threshold
        self.remainingPercentage = remainingPercentage
    }

    public var title: String {
        "CodexMeter quota alert"
    }

    public var body: String {
        "Codex quota remaining \(remainingPercentage)%, consider switching tasks."
    }
}

public struct NotificationEvaluation: Equatable, Sendable {
    public let decision: NotificationDecision?
    public let reachedThresholds: Set<Int>

    public init(decision: NotificationDecision?, reachedThresholds: Set<Int>) {
        self.decision = decision
        self.reachedThresholds = reachedThresholds
    }
}

public struct NotificationPolicy: Sendable {
    public static let thresholds = [50, 30, 10]

    public init() {}

    public func evaluate(
        previousRemainingPercentage: Double?,
        remainingPercentage: Double,
        previouslySent: Set<Int>
    ) -> NotificationEvaluation {
        let clampedRemaining = min(max(remainingPercentage, 0), 100)
        let remaining = Int(clampedRemaining.rounded())
        let crossed = Set(Self.thresholds.filter { threshold in
            guard let previousRemainingPercentage else {
                return clampedRemaining <= Double(threshold)
            }

            return previousRemainingPercentage > Double(threshold)
                && clampedRemaining <= Double(threshold)
        })
        let newlyReached = crossed.subtracting(previouslySent)
        let decision = newlyReached.min().map {
            NotificationDecision(threshold: $0, remainingPercentage: remaining)
        }

        return NotificationEvaluation(
            decision: decision,
            reachedThresholds: previouslySent.union(crossed)
        )
    }
}

public enum NotificationCycleKey {
    public static func make(for quota: QuotaStatus) -> String {
        let accountHash = stableHash(quota.account ?? "default")
        let duration = quota.windowDurationMinutes.map(String.init) ?? "unknown"
        let reset = quota.resetTime
            .map { String(Int($0.timeIntervalSince1970)) } ?? "unknown"

        return [
            quota.provider.rawValue,
            accountHash,
            quota.limitID,
            quota.id,
            duration,
            reset
        ].joined(separator: "|")
    }

    private static func stableHash(_ value: String) -> String {
        var hash: UInt64 = 14_695_981_039_346_656_037
        for byte in value.utf8 {
            hash ^= UInt64(byte)
            hash &*= 1_099_511_628_211
        }
        return String(hash, radix: 16)
    }
}
