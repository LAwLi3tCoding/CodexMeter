import Foundation
import CodexMeterCore

extension TestRegistry {
    static let quotaStatus = [
        HarnessTest(
            suite: "domain",
            name: "Quota clamps usage above one hundred percent",
            body: testQuotaClampsRemainingPercentage
        ),
        HarnessTest(
            suite: "domain",
            name: "Quota clamps negative usage",
            body: testQuotaClampsNegativeUsage
        ),
        HarnessTest(
            suite: "domain",
            name: "Quota preserves window metadata",
            body: testQuotaPreservesWindowMetadata
        ),
        HarnessTest(
            suite: "domain",
            name: "Provider snapshot groups provider metadata and quotas",
            body: testProviderSnapshotGroupsProviderMetadataAndQuotas
        )
    ]
}

private func testQuotaClampsRemainingPercentage() async throws {
    let quota = QuotaStatus.makeForTest(usedPercent: 125)

    expectEqual(quota.used, 100)
    expectEqual(quota.remaining, 0)
    expectEqual(quota.percentage, 0)
}

private func testQuotaClampsNegativeUsage() async throws {
    let quota = QuotaStatus.makeForTest(usedPercent: -25)

    expectEqual(quota.used, 0)
    expectEqual(quota.remaining, 100)
    expectEqual(quota.percentage, 100)
}

private func testQuotaPreservesWindowMetadata() async throws {
    let resetTime = Date(timeIntervalSince1970: 1_730_947_200)
    let updatedAt = Date(timeIntervalSince1970: 1_730_900_000)
    let quota = QuotaStatus.makeForTest(
        usedPercent: 25,
        resetTime: resetTime,
        windowDurationMinutes: 300,
        updatedAt: updatedAt
    )

    expectEqual(quota.id, "codex.primary")
    expectEqual(quota.provider, .codex)
    expectEqual(quota.account, "developer@example.com")
    expectEqual(quota.model, "gpt-5.5")
    expectEqual(quota.limitID, "codex")
    expectEqual(quota.label, "Codex")
    expectEqual(quota.used, 25)
    expectEqual(quota.remaining, 75)
    expectEqual(quota.percentage, 75)
    expectEqual(quota.resetTime, resetTime)
    expectEqual(quota.windowDurationMinutes, 300)
    expectEqual(quota.updatedAt, updatedAt)
}

private func testProviderSnapshotGroupsProviderMetadataAndQuotas() async throws {
    let updatedAt = Date(timeIntervalSince1970: 1_730_900_000)
    let quota = QuotaStatus.makeForTest(usedPercent: 25, updatedAt: updatedAt)
    let snapshot = ProviderSnapshot(
        provider: .codex,
        account: "developer@example.com",
        plan: "plus",
        model: "gpt-5.5",
        quotas: [quota],
        updatedAt: updatedAt
    )

    expectEqual(snapshot.provider, .codex)
    expectEqual(snapshot.account, "developer@example.com")
    expectEqual(snapshot.plan, "plus")
    expectEqual(snapshot.model, "gpt-5.5")
    expectEqual(snapshot.quotas, [quota])
    expectEqual(snapshot.updatedAt, updatedAt)
}

private extension QuotaStatus {
    static func makeForTest(
        usedPercent: Double,
        resetTime: Date? = nil,
        windowDurationMinutes: Int? = nil,
        updatedAt: Date = Date(timeIntervalSince1970: 1_730_900_000)
    ) -> QuotaStatus {
        QuotaStatus(
            id: "codex.primary",
            provider: .codex,
            account: "developer@example.com",
            model: "gpt-5.5",
            limitID: "codex",
            label: "Codex",
            usedPercent: usedPercent,
            resetTime: resetTime,
            windowDurationMinutes: windowDurationMinutes,
            updatedAt: updatedAt
        )
    }
}
