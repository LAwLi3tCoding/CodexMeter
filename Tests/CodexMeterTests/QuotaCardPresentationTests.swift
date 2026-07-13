import Foundation
import CodexMeterCore

let quotaCardPresentation: [HarnessTest] = [
    HarnessTest(
        suite: "ui-presentation",
        name: "Quota card formats remaining and reset details",
        body: testQuotaCardFormatting
    ),
    HarnessTest(
        suite: "ui-presentation",
        name: "Quota card assigns semantic levels",
        body: testQuotaCardLevels
    ),
    HarnessTest(
        suite: "ui-presentation",
        name: "Panel header masks account metadata",
        body: testPanelHeaderFormatting
    ),
    HarnessTest(
        suite: "ui-presentation",
        name: "Panel header identifies API key accounts",
        body: testAPIKeyAccountFormatting
    )
]

private func testQuotaCardFormatting() {
    let now = Date(timeIntervalSince1970: 0)
    let quota = makePresentationQuota(
        usedPercent: 22,
        resetTime: Date(timeIntervalSince1970: 13_320)
    )
    let presentation = QuotaCardPresentation(
        quota: quota,
        now: now,
        timeZone: TimeZone(secondsFromGMT: 0)!
    )

    expectEqual(presentation.title, "5 小时额度")
    expectEqual(presentation.percentageText, "78%")
    expectEqual(presentation.remainingText, "剩余 78%")
    expectEqual(presentation.countdownText, "3h42m")
    expectEqual(presentation.resetText, "重置 03:42")
    expectEqual(presentation.progress, 0.78)
    expectEqual(
        presentation.accessibilityLabel,
        "5 小时额度，模型 gpt-5.5，剩余 78%，距重置 3h42m，重置 03:42"
    )
}

private func testQuotaCardLevels() {
    let healthy = QuotaCardPresentation(quota: makePresentationQuota(usedPercent: 20))
    let warning = QuotaCardPresentation(quota: makePresentationQuota(usedPercent: 55))
    let low = QuotaCardPresentation(quota: makePresentationQuota(usedPercent: 75))
    let critical = QuotaCardPresentation(quota: makePresentationQuota(usedPercent: 92))

    expectEqual(healthy.level, .healthy)
    expectEqual(warning.level, .warning)
    expectEqual(low.level, .low)
    expectEqual(critical.level, .critical)
}

private func testPanelHeaderFormatting() {
    let quota = makePresentationQuota(usedPercent: 20)
    let snapshot = ProviderSnapshot(
        provider: .codex,
        account: "developer@example.com",
        plan: "plus",
        model: "gpt-5.5",
        quotas: [quota],
        updatedAt: quota.updatedAt
    )
    let presentation = StatusPanelPresentation(
        snapshot: snapshot,
        timeZone: TimeZone(secondsFromGMT: 0)!
    )

    expectEqual(presentation.accountText, "dev***@example.com")
    expectEqual(presentation.planText, "PLUS")
    expectEqual(presentation.modelText, "gpt-5.5")
    expectEqual(presentation.updatedText, "更新于 00:08")
}

private func testAPIKeyAccountFormatting() {
    let quota = makePresentationQuota(usedPercent: 20)
    let snapshot = ProviderSnapshot(
        provider: .codex,
        account: nil,
        accountKind: .apiKey,
        plan: nil,
        model: "Codex",
        quotas: [quota],
        updatedAt: quota.updatedAt
    )

    let presentation = StatusPanelPresentation(snapshot: snapshot)

    expectEqual(presentation.accountText, "API key account")
}

private func makePresentationQuota(
    usedPercent: Double,
    resetTime: Date? = nil
) -> QuotaStatus {
    QuotaStatus(
        id: "codex.primary",
        provider: .codex,
        account: "developer@example.com",
        model: "gpt-5.5",
        limitID: "codex",
        label: "5 小时额度",
        usedPercent: usedPercent,
        resetTime: resetTime,
        windowDurationMinutes: 300,
        updatedAt: Date(timeIntervalSince1970: 500)
    )
}
