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
        name: "Menu bar has a stable empty state",
        body: testMenuBarEmptyState
    ),
    HarnessTest(
        suite: "presentation",
        name: "Menu bar label combines percentage and countdown",
        body: testMenuBarLabelCombinesPercentageAndCountdown
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
    expectEqual(presentation.accessibilityLabel, "Codex 剩余 40%，3h45m 后重置")
}

private func testMenuBarEmptyState() {
    let presentation = MenuBarPresentation(quotas: [], now: .distantPast)

    expectEqual(presentation.percentageText, "--")
    expectNil(presentation.countdownText)
    expectEqual(presentation.accessibilityLabel, "Codex 额度暂不可用")
}

private func testMenuBarLabelCombinesPercentageAndCountdown() {
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

private func makeQuota(id: String, remaining: Double, resetTime: Date?) -> QuotaStatus {
    QuotaStatus(
        id: id,
        provider: .codex,
        account: nil,
        model: "Codex",
        limitID: "codex",
        label: "Codex",
        usedPercent: 100 - remaining,
        resetTime: resetTime,
        windowDurationMinutes: nil,
        updatedAt: .distantPast
    )
}
