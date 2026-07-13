import Foundation
import CodexMeterCore

let notificationPolicy: [HarnessTest] = [
    HarnessTest(
        suite: "notification",
        name: "Initial low observation emits only the most severe threshold",
        body: testInitialLowObservation
    ),
    HarnessTest(
        suite: "notification",
        name: "Threshold decisions are deduplicated",
        body: testThresholdDeduplication
    ),
    HarnessTest(
        suite: "notification",
        name: "Cycle keys avoid plaintext accounts and change after reset",
        body: testCycleKeys
    ),
    HarnessTest(
        suite: "notification",
        name: "Upward correction does not emit a threshold notification",
        body: testUpwardCorrection
    )
]

private func testInitialLowObservation() {
    let evaluation = NotificationPolicy().evaluate(
        previousRemainingPercentage: nil,
        remainingPercentage: 8,
        previouslySent: []
    )

    expectEqual(evaluation.decision?.threshold, 10)
    expectEqual(evaluation.reachedThresholds, Set([50, 30, 10]))
}

private func testThresholdDeduplication() {
    let policy = NotificationPolicy()
    let evaluation = policy.evaluate(
        previousRemainingPercentage: 40,
        remainingPercentage: 25,
        previouslySent: [50]
    )
    let repeated = policy.evaluate(
        previousRemainingPercentage: 25,
        remainingPercentage: 25,
        previouslySent: evaluation.reachedThresholds
    )

    expectEqual(evaluation.decision?.threshold, 30)
    expectEqual(evaluation.reachedThresholds, Set([50, 30]))
    expectNil(repeated.decision)
}

private func testUpwardCorrection() {
    let evaluation = NotificationPolicy().evaluate(
        previousRemainingPercentage: 25,
        remainingPercentage: 35,
        previouslySent: []
    )

    expectNil(evaluation.decision)
}

private func testCycleKeys() {
    let first = quotaFixture(resetTime: Date(timeIntervalSince1970: 1_000))
    let second = quotaFixture(resetTime: Date(timeIntervalSince1970: 2_000))
    let firstKey = NotificationCycleKey.make(for: first)
    let secondKey = NotificationCycleKey.make(for: second)

    if firstKey.contains("developer@example.com") {
        TestRecorder.record("cycle key must not contain a plaintext account")
    }
    if firstKey == secondKey {
        TestRecorder.record("cycle key must change for a new reset cycle")
    }
}

private func quotaFixture(resetTime: Date?) -> QuotaStatus {
    QuotaStatus(
        id: "codex.primary",
        provider: .codex,
        account: "developer@example.com",
        model: "gpt-test",
        limitID: "codex",
        label: "5 小时额度",
        usedPercent: 75,
        resetTime: resetTime,
        windowDurationMinutes: 300,
        updatedAt: Date(timeIntervalSince1970: 500)
    )
}
