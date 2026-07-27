import Foundation
import CodexMeterCore

let menuBarPresentation: [HarnessTest] = [
    HarnessTest(
        suite: "presentation",
        name: "Menu bar uses the most constrained quota",
        body: testMenuBarUsesMostConstrainedQuota
    ),
    HarnessTest(
        suite: "presentation",
        name: "Menu bar prefers advanced model quota over a tighter Spark quota",
        body: testMenuBarPrefersAdvancedModelQuota
    ),
    HarnessTest(
        suite: "presentation",
        name: "Menu bar falls back when advanced model quota is unavailable",
        body: testMenuBarFallsBackWithoutAdvancedModelQuota
    ),
    HarnessTest(
        suite: "presentation",
        name: "Menu bar has a stable empty state",
        body: testMenuBarEmptyState
    ),
    HarnessTest(
        suite: "presentation",
        name: "Menu bar keeps a compact remaining percentage visible",
        body: testMenuBarKeepsCompactPercentageVisible
    ),
    HarnessTest(
        suite: "presentation",
        name: "Menu bar label omits countdown without reset",
        body: testMenuBarLabelOmitsCountdownWithoutReset
    )
]

private func testMenuBarUsesMostConstrainedQuota() {
    let now = Date(timeIntervalSince1970: 1_730_900_000)
    let presentation = MenuBarPresentation(
        quotas: [
            makeQuota(id: "codex.primary", remaining: 72, resetTime: now.addingTimeInterval(14_400)),
            makeQuota(id: "codex.secondary", remaining: 40, resetTime: now.addingTimeInterval(13_500))
        ],
        now: now
    )

    expectEqual(presentation.percentageText, "40%")
    expectEqual(presentation.countdownText, "3h45m")
    expectEqual(presentation.accessibilityLabel, "Codex 40% remaining, resets in 3h45m")
    expectEqual(presentation.brandText, "Codex")
    expectEqual(presentation.systemImageName, "gauge.medium")
}

private func testMenuBarPrefersAdvancedModelQuota() {
    let now = Date(timeIntervalSince1970: 1_730_900_000)
    let presentation = MenuBarPresentation(
        quotas: [
            makeQuota(
                id: "codex.primary",
                limitID: "codex",
                remaining: 72,
                resetTime: now.addingTimeInterval(14_400)
            ),
            makeQuota(
                id: "codex.secondary",
                limitID: "codex",
                remaining: 40,
                resetTime: now.addingTimeInterval(13_500)
            ),
            makeQuota(
                id: "codex_spark.primary",
                limitID: "codex_spark",
                remaining: 5,
                resetTime: now.addingTimeInterval(1_800)
            )
        ],
        now: now
    )

    expectEqual(presentation.percentageText, "40%")
    expectEqual(presentation.countdownText, "3h45m")
}

private func testMenuBarFallsBackWithoutAdvancedModelQuota() {
    let now = Date(timeIntervalSince1970: 1_730_900_000)
    let presentation = MenuBarPresentation(
        quotas: [
            makeQuota(
                id: "codex_spark.primary",
                limitID: "codex_spark",
                remaining: 60,
                resetTime: now.addingTimeInterval(7_200)
            ),
            makeQuota(
                id: "codex_spark.secondary",
                limitID: "codex_spark",
                remaining: 25,
                resetTime: now.addingTimeInterval(3_600)
            )
        ],
        now: now
    )

    expectEqual(presentation.percentageText, "25%")
    expectEqual(presentation.countdownText, "1h0m")
}

private func testMenuBarEmptyState() {
    let presentation = MenuBarPresentation(quotas: [], now: .distantPast)

    expectEqual(presentation.displayText, "Codex --")
    expectEqual(presentation.percentageText, "--")
    expectNil(presentation.countdownText)
    expectEqual(presentation.accessibilityLabel, "Codex quota unavailable")
    expectEqual(presentation.brandText, "Codex")
    expectEqual(presentation.systemImageName, "gauge.medium")
}

private func testMenuBarKeepsCompactPercentageVisible() {
    let now = Date(timeIntervalSince1970: 1_730_900_000)
    let presentation = MenuBarPresentation(
        quotas: [
            makeQuota(
                id: "codex.primary",
                remaining: 72,
                resetTime: now.addingTimeInterval((3 * 60 * 60) + (45 * 60))
            )
        ],
        now: now
    )

    expectEqual(presentation.displayText, "Codex 72%")
    expectEqual(presentation.labelText, "72% · 3h45m")
}

private func testMenuBarLabelOmitsCountdownWithoutReset() {
    let presentation = MenuBarPresentation(
        quotas: [makeQuota(id: "codex.primary", remaining: 72, resetTime: nil)],
        now: .distantPast
    )

    expectEqual(presentation.labelText, "72%")
    expectNil(presentation.countdownText)
}

private func makeQuota(
    id: String,
    limitID: String = "codex",
    remaining: Double,
    resetTime: Date?
) -> QuotaStatus {
    QuotaStatus(
        id: id,
        provider: .codex,
        account: nil,
        model: "Codex",
        limitID: limitID,
        label: "Codex",
        usedPercent: 100 - remaining,
        resetTime: resetTime,
        windowDurationMinutes: nil,
        updatedAt: .distantPast
    )
}
