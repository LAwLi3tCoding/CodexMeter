import Foundation
import CodexMeterCore

let widgetPresentation: [HarnessTest] = [
    HarnessTest(
        suite: "widget",
        name: "Widget presentation puts the most constrained quota first",
        body: testWidgetPresentationQuotaOrdering
    ),
    HarnessTest(
        suite: "widget",
        name: "Widget quota presentation formats percentage countdown and segments",
        body: testWidgetQuotaPresentationFormatting
    ),
    HarnessTest(
        suite: "widget",
        name: "Widget quota levels keep exact fifty and twenty boundaries",
        body: testWidgetQuotaLevelBoundaries
    ),
    HarnessTest(
        suite: "widget",
        name: "Widget presentation becomes stale at fifteen minutes",
        body: testWidgetPresentationStaleBoundary
    ),
    HarnessTest(
        suite: "widget",
        name: "Widget timeline covers one hour in five minute increments",
        body: testWidgetTimelineDates
    )
]

private func testWidgetPresentationQuotaOrdering() {
    let now = Date(timeIntervalSince1970: 1_730_900_000)
    let snapshot = makePresentationWidgetSnapshot(
        quotas: [
            makeWidgetQuota(
                id: "healthy",
                remainingPercent: 72,
                resetTime: now.addingTimeInterval(3_600)
            ),
            makeWidgetQuota(
                id: "later-reset",
                remainingPercent: 20,
                resetTime: now.addingTimeInterval(7_200)
            ),
            makeWidgetQuota(
                id: "earlier-reset",
                remainingPercent: 20,
                resetTime: now.addingTimeInterval(1_800)
            )
        ],
        updatedAt: now
    )

    let presentation = WidgetQuotaPresentation(snapshot: snapshot, now: now)

    expectEqual(
        presentation.quotas.map(\.id),
        ["earlier-reset", "later-reset", "healthy"]
    )
    expectEqual(presentation.quotas.first?.id, "earlier-reset")
    expectEqual(presentation.modelText, "gpt-5.5")
}

private func testWidgetQuotaPresentationFormatting() {
    let now = Date(timeIntervalSince1970: 1_730_900_000)
    let snapshot = makePresentationWidgetSnapshot(
        quotas: [
            makeWidgetQuota(
                id: "primary",
                remainingPercent: 65,
                resetTime: now.addingTimeInterval(13_500)
            )
        ],
        updatedAt: now
    )

    let item = WidgetQuotaPresentation(snapshot: snapshot, now: now).quotas[0]

    expectEqual(item.label, "5 小时额度")
    expectEqual(item.percentageText, "65%")
    expectEqual(item.countdownText, "3h45m")
    expectEqual(
        item.segmentFillAmounts,
        [1, 1, 1, 1, 1, 1, 0.5, 0, 0, 0]
    )
    expectEqual(item.level, .healthy)
}

private func testWidgetQuotaLevelBoundaries() {
    let now = Date(timeIntervalSince1970: 1_730_900_000)
    let snapshot = makePresentationWidgetSnapshot(
        quotas: [
            makeWidgetQuota(id: "healthy", remainingPercent: 50),
            makeWidgetQuota(id: "warning", remainingPercent: 20),
            makeWidgetQuota(id: "critical", remainingPercent: 19.9)
        ],
        updatedAt: now
    )
    let items = WidgetQuotaPresentation(snapshot: snapshot, now: now).quotas
    let levels = Dictionary(uniqueKeysWithValues: items.map { ($0.id, $0.level) })

    expectEqual(levels["healthy"], .healthy)
    expectEqual(levels["warning"], .warning)
    expectEqual(levels["critical"], .critical)
}

private func testWidgetPresentationStaleBoundary() {
    let updatedAt = Date(timeIntervalSince1970: 1_730_900_000)
    let snapshot = makePresentationWidgetSnapshot(
        quotas: [makeWidgetQuota(id: "primary", remainingPercent: 72)],
        updatedAt: updatedAt
    )

    expectEqual(
        WidgetQuotaPresentation(
            snapshot: snapshot,
            now: updatedAt.addingTimeInterval(899)
        ).isStale,
        false
    )
    expectEqual(
        WidgetQuotaPresentation(
            snapshot: snapshot,
            now: updatedAt.addingTimeInterval(900)
        ).isStale,
        true
    )
}

private func testWidgetTimelineDates() {
    let now = Date(timeIntervalSince1970: 1_730_900_000)
    let dates = WidgetTimelinePolicy.entryDates(start: now)

    expectEqual(dates.count, 13)
    expectEqual(dates[0], now)
    expectEqual(dates[1], now.addingTimeInterval(300))
    expectEqual(dates[12], now.addingTimeInterval(3_600))
}

private func makePresentationWidgetSnapshot(
    quotas: [QuotaStatus],
    updatedAt: Date
) -> WidgetQuotaSnapshot {
    WidgetQuotaSnapshot(
        snapshot: ProviderSnapshot(
            provider: .codex,
            account: "developer@example.com",
            plan: "plus",
            model: "gpt-5.5",
            quotas: quotas,
            updatedAt: updatedAt
        )
    )
}

private func makeWidgetQuota(
    id: String,
    remainingPercent: Double,
    resetTime: Date? = nil
) -> QuotaStatus {
    QuotaStatus(
        id: id,
        provider: .codex,
        account: "developer@example.com",
        model: "gpt-5.5",
        limitID: "codex",
        label: "5 小时额度",
        usedPercent: 100 - remainingPercent,
        resetTime: resetTime,
        windowDurationMinutes: 300,
        updatedAt: Date(timeIntervalSince1970: 1_730_900_000)
    )
}
