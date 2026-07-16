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
        name: "Quota card keeps exact levels while displaying conservative integers",
        body: testQuotaCardLevelsAndDisplayedPercentages
    ),
    HarnessTest(
        suite: "ui-presentation",
        name: "Rounded used and remaining values total one hundred",
        body: testQuotaCardRoundedTotal
    ),
    HarnessTest(
        suite: "ui-presentation",
        name: "Empty quota gauge exposes ten empty segments",
        body: testQuotaGaugeAtZero
    ),
    HarnessTest(
        suite: "ui-presentation",
        name: "Quota gauge exposes a partially filled segment",
        body: testQuotaGaugePartialSegment
    ),
    HarnessTest(
        suite: "ui-presentation",
        name: "Quota gauge preserves an exact segment boundary",
        body: testQuotaGaugeBoundary
    ),
    HarnessTest(
        suite: "ui-presentation",
        name: "Full quota gauge exposes ten filled segments",
        body: testQuotaGaugeAtOneHundred
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
        name: "Panel header labels the Pro twenty-times tier",
        body: testProTwentyTimesPlanFormatting
    ),
    HarnessTest(
        suite: "ui-presentation",
        name: "Non-Codex providers keep their own Pro label",
        body: testNonCodexProPlanFormatting
    ),
    HarnessTest(
        suite: "ui-presentation",
        name: "Panel keeps and sorts every quota card",
        body: testPanelQuotaCardOrdering
    ),
    HarnessTest(
        suite: "ui-presentation",
        name: "Panel keeps two through four quota cards unscrolled",
        body: testPanelCommonQuotaCountsDoNotRequireOverflow
    ),
    HarnessTest(
        suite: "ui-presentation",
        name: "Panel requires overflow beyond four quota cards",
        body: testPanelLargeQuotaCountRequiresOverflow
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

    expectEqual(presentation.title, "5-hour quota")
    expectEqual(presentation.percentageText, "78%")
    expectEqual(presentation.remainingText, "78% remaining")
    expectEqual(presentation.usedText, "22% used")
    expectEqual(presentation.countdownText, "3h42m")
    expectEqual(presentation.resetText, "Resets at 03:42")
    expectEqual(presentation.progress, 0.78)
    expectEqual(
        presentation.accessibilityLabel,
        "5-hour quota, model gpt-5.5, 78% remaining, 22% used, resets in 3h42m, resets at 03:42"
    )
}

private func testQuotaCardLevelsAndDisplayedPercentages() {
    let healthy = QuotaCardPresentation(quota: makePresentationQuota(usedPercent: 50))
    let warningBelowFifty = QuotaCardPresentation(quota: makePresentationQuota(usedPercent: 50.1))
    let warningAtTwenty = QuotaCardPresentation(quota: makePresentationQuota(usedPercent: 80))
    let criticalBelowTwenty = QuotaCardPresentation(quota: makePresentationQuota(usedPercent: 80.1))

    expectEqual(healthy.level, .healthy)
    expectEqual(healthy.percentageText, "50%")
    expectEqual(warningBelowFifty.level, .warning)
    expectEqual(warningBelowFifty.percentageText, "49%")
    expectEqual(warningAtTwenty.level, .warning)
    expectEqual(warningAtTwenty.percentageText, "20%")
    expectEqual(criticalBelowTwenty.level, .critical)
    expectEqual(criticalBelowTwenty.percentageText, "19%")
}

private func testQuotaCardRoundedTotal() {
    let presentation = QuotaCardPresentation(
        quota: makePresentationQuota(usedPercent: 33.5)
    )

    expectEqual(presentation.usedText, "34% used")
    expectEqual(presentation.remainingText, "66% remaining")
}

private func testQuotaGaugeAtZero() {
    let presentation = QuotaCardPresentation(
        quota: makePresentationQuota(usedPercent: 100)
    )

    expectEqual(presentation.segmentFillAmounts.count, 10)
    expectEqual(presentation.segmentFillAmounts, Array(repeating: 0, count: 10))
}

private func testQuotaGaugePartialSegment() {
    let presentation = QuotaCardPresentation(
        quota: makePresentationQuota(usedPercent: 35)
    )

    expectEqual(
        presentation.segmentFillAmounts,
        [1, 1, 1, 1, 1, 1, 0.5, 0, 0, 0]
    )
}

private func testQuotaGaugeBoundary() {
    let presentation = QuotaCardPresentation(
        quota: makePresentationQuota(usedPercent: 80)
    )

    expectEqual(
        presentation.segmentFillAmounts,
        [1, 1, 0, 0, 0, 0, 0, 0, 0, 0]
    )
}

private func testQuotaGaugeAtOneHundred() {
    let presentation = QuotaCardPresentation(
        quota: makePresentationQuota(usedPercent: 0)
    )

    expectEqual(presentation.segmentFillAmounts.count, 10)
    expectEqual(presentation.segmentFillAmounts, Array(repeating: 1, count: 10))
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
    expectEqual(presentation.updatedText, "Updated at 00:08")
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

private func testProTwentyTimesPlanFormatting() {
    let quota = makePresentationQuota(usedPercent: 20)
    let snapshot = ProviderSnapshot(
        provider: .codex,
        account: nil,
        accountKind: .chatGPT,
        plan: "pro",
        model: "Codex",
        quotas: [quota],
        updatedAt: quota.updatedAt
    )

    let presentation = StatusPanelPresentation(snapshot: snapshot)

    expectEqual(presentation.planText, "PRO 20X")
}

private func testNonCodexProPlanFormatting() {
    let quota = makePresentationQuota(usedPercent: 20)
    let snapshot = ProviderSnapshot(
        provider: .openAI,
        account: nil,
        accountKind: .unknown,
        plan: "pro",
        model: "OpenAI",
        quotas: [quota],
        updatedAt: quota.updatedAt
    )

    let presentation = StatusPanelPresentation(snapshot: snapshot)

    expectEqual(presentation.planText, "PRO")
}

private func testPanelQuotaCardOrdering() {
    let quotas = [
        makePresentationQuota(
            id: "codex.secondary",
            limitID: "codex",
            label: "Weekly quota",
            usedPercent: 40,
            windowDurationMinutes: 10_080
        ),
        makePresentationQuota(
            id: "unknown.primary",
            limitID: "unknown",
            label: "Quota",
            usedPercent: 10,
            windowDurationMinutes: nil
        ),
        makePresentationQuota(
            id: "codex_spark.primary",
            limitID: "codex_spark",
            label: "5-hour quota",
            usedPercent: 5,
            windowDurationMinutes: 300
        ),
        makePresentationQuota(
            id: "codex.primary",
            limitID: "codex",
            label: "5-hour quota",
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

private func testPanelCommonQuotaCountsDoNotRequireOverflow() {
    for count in 2...4 {
        let presentation = makePanelPresentation(quotaCount: count)

        expectEqual(presentation.requiresQuotaOverflow, false)
    }
}

private func testPanelLargeQuotaCountRequiresOverflow() {
    let presentation = makePanelPresentation(quotaCount: 5)

    expectEqual(presentation.requiresQuotaOverflow, true)
}

private func makePanelPresentation(quotaCount: Int) -> StatusPanelPresentation {
    let quotas = (0..<quotaCount).map { index in
        makePresentationQuota(
            id: "codex.\(index)",
            limitID: "codex.\(index)",
            usedPercent: Double(index)
        )
    }
    let snapshot = ProviderSnapshot(
        provider: .codex,
        account: "developer@example.com",
        plan: "pro",
        model: "gpt-5.5",
        quotas: quotas,
        updatedAt: Date(timeIntervalSince1970: 500)
    )

    return StatusPanelPresentation(snapshot: snapshot)
}

private func makePresentationQuota(
    id: String = "codex.primary",
    limitID: String = "codex",
    label: String = "5-hour quota",
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
