import Foundation
import CodexMeterCore

extension TestRegistry {
    static let quotaFormatter = [
        HarnessTest(
            suite: "domain",
            name: "Five-hour window label",
            body: testFiveHourWindowLabel
        ),
        HarnessTest(
            suite: "domain",
            name: "Weekly window label",
            body: testWeeklyWindowLabel
        ),
        HarnessTest(
            suite: "domain",
            name: "Minute window label",
            body: testMinuteWindowLabel
        ),
        HarnessTest(
            suite: "domain",
            name: "Missing window duration label",
            body: testMissingWindowDurationLabel
        ),
        HarnessTest(
            suite: "domain",
            name: "Reset countdown",
            body: testResetCountdown
        ),
        HarnessTest(
            suite: "domain",
            name: "Account email masking",
            body: testAccountEmailMasking
        ),
        HarnessTest(
            suite: "domain",
            name: "Non-email account masking",
            body: testNonEmailAccountMasking
        )
    ]
}

private func testFiveHourWindowLabel() async throws {
    expectEqual(QuotaFormatter.windowLabel(minutes: 300), "5 小时额度")
}

private func testWeeklyWindowLabel() async throws {
    expectEqual(QuotaFormatter.windowLabel(minutes: 10_080), "周额度")
}

private func testMinuteWindowLabel() async throws {
    expectEqual(QuotaFormatter.windowLabel(minutes: 90), "90 分钟额度")
}

private func testMissingWindowDurationLabel() async throws {
    expectEqual(QuotaFormatter.windowLabel(minutes: nil), "额度")
}

private func testResetCountdown() async throws {
    let now = Date(timeIntervalSince1970: 1_730_900_000)
    let reset = now.addingTimeInterval((3 * 60 * 60) + (45 * 60))
    let threeDays: TimeInterval = 3 * 86_400
    let twoHours: TimeInterval = 2 * 3_600
    let fiveMinutes: TimeInterval = 5 * 60
    let multiDayReset = now.addingTimeInterval(threeDays + twoHours + fiveMinutes)

    expectEqual(QuotaFormatter.countdown(until: reset, now: now), "3h45m")
    expectEqual(QuotaFormatter.countdown(until: multiDayReset, now: now), "3d2h5m")
    expectEqual(QuotaFormatter.countdown(until: now.addingTimeInterval(30), now: now), "1m")
    expectEqual(QuotaFormatter.countdown(until: now, now: now), "即将重置")
    expectEqual(QuotaFormatter.countdown(until: nil, now: now), "—")
}

private func testAccountEmailMasking() async throws {
    expectEqual(
        QuotaFormatter.maskedAccount("developer@example.com"),
        "dev***@example.com"
    )
    expectNil(QuotaFormatter.maskedAccount(nil))
}

private func testNonEmailAccountMasking() {
    expectEqual(QuotaFormatter.maskedAccount("organization-user-123"), "org***")
}
