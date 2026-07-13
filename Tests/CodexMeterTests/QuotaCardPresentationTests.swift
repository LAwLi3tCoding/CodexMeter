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
        name: "Rounded used and remaining values total one hundred",
        body: testQuotaCardRoundedTotal
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
    ),
    HarnessTest(
        suite: "ui-presentation",
        name: "Panel keeps and sorts every quota card",
        body: testPanelQuotaCardOrdering
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
    expectEqual(presentation.usedText, "已用 22%")
    expectEqual(presentation.countdownText, "3h42m")
    expectEqual(presentation.resetText, "重置 03:42")
    expectEqual(presentation.progress, 0.78)
    expectEqual(
        presentation.accessibilityLabel,
        "5 小时额度，模型 gpt-5.5，剩余 78%，已用 22%，距重置 3h42m，重置 03:42"
    )
}

private func testQuotaCardLevels() {
    let healthy = QuotaCardPresentation(quota: makePresentationQuota(usedPercent: 50))
    let warningBelowFifty = QuotaCardPresentation(quota: makePresentationQuota(usedPercent: 50.1))
    let warningAtTwenty = QuotaCardPresentation(quota: makePresentationQuota(usedPercent: 80))
    let criticalBelowTwenty = QuotaCardPresentation(quota: makePresentationQuota(usedPercent: 80.1))

    expectEqual(healthy.level, .healthy)
    expectEqual(warningBelowFifty.level, .warning)
    expectEqual(warningAtTwenty.level, .warning)
    expectEqual(criticalBelowTwenty.level, .critical)
}

private func testQuotaCardRoundedTotal() {
    let presentation = QuotaCardPresentation(
        quota: makePresentationQuota(usedPercent: 33.5)
    )

    expectEqual(presentation.usedText, "已用 33%")
    expectEqual(presentation.remainingText, "剩余 67%")
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

private func testPanelQuotaCardOrdering() {
    let quotas = [
        makePresentationQuota(
            id: "codex.secondary",
            limitID: "codex",
            label: "周额度",
            usedPercent: 40,
            windowDurationMinutes: 10_080
        ),
        makePresentationQuota(
            id: "unknown.primary",
            limitID: "unknown",
            label: "额度",
            usedPercent: 10,
            windowDurationMinutes: nil
        ),
        makePresentationQuota(
            id: "codex_spark.primary",
            limitID: "codex_spark",
            label: "5 小时额度",
            usedPercent: 5,
            windowDurationMinutes: 300
        ),
        makePresentationQuota(
            id: "codex.primary",
            limitID: "codex",
            label: "5 小时额度",
            usedPercent: 20,
            windowDurationMinutes: 300
        )
    ]
    let snapshot = ProviderSnapshot(
        provider: .codex,
        account: "developer@example.com",
        plan: "pro",
        model: "gpt-5.5",
        quotas: quotas,
        updatedAt: Date(timeIntervalSince1970: 500)
    )

    let presentation = StatusPanelPresentation(snapshot: snapshot)

    expectEqual(
        presentation.quotaCards.map(\.id),
        [
            "codex.primary",
            "codex_spark.primary",
            "codex.secondary",
            "unknown.primary"
        ]
    )
}

private func makePresentationQuota(
    id: String = "codex.primary",
    limitID: String = "codex",
    label: String = "5 小时额度",
    model: String = "gpt-5.5",
    usedPercent: Double,
    resetTime: Date? = nil,
    windowDurationMinutes: Int? = 300
) -> QuotaStatus {
    QuotaStatus(
        id: id,
        provider: .codex,
        account: "developer@example.com",
        model: model,
        limitID: limitID,
        label: label,
        usedPercent: usedPercent,
        resetTime: resetTime,
        windowDurationMinutes: windowDurationMinutes,
        updatedAt: Date(timeIntervalSince1970: 500)
    )
}
