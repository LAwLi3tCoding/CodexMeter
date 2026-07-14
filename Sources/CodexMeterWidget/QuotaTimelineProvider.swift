import Foundation
import WidgetKit
import CodexMeterCore

struct QuotaWidgetEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetQuotaSnapshot?
}

struct QuotaTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> QuotaWidgetEntry {
        let now = Date()
        return QuotaWidgetEntry(
            date: now,
            snapshot: Self.placeholderSnapshot(now: now)
        )
    }

    func getSnapshot(
        in context: Context,
        completion: @escaping (QuotaWidgetEntry) -> Void
    ) {
        let now = Date()
        completion(
            QuotaWidgetEntry(
                date: now,
                snapshot: context.isPreview
                    ? Self.placeholderSnapshot(now: now)
                    : Self.loadSnapshot()
            )
        )
    }

    func getTimeline(
        in context: Context,
        completion: @escaping (Timeline<QuotaWidgetEntry>) -> Void
    ) {
        let now = Date()
        let snapshot = Self.loadSnapshot()
        let entries = WidgetTimelinePolicy.entryDates(start: now).map { date in
            QuotaWidgetEntry(date: date, snapshot: snapshot)
        }
        completion(
            Timeline(
                entries: entries,
                policy: .after(entries.last?.date ?? now.addingTimeInterval(3_600))
            )
        )
    }

    private static func loadSnapshot() -> WidgetQuotaSnapshot? {
        WidgetSnapshotStore.sharedApplicationSupport()?.read()
    }

    private static func placeholderSnapshot(now: Date) -> WidgetQuotaSnapshot {
        let quotas = [
            QuotaStatus(
                id: "codex.primary",
                provider: .codex,
                account: nil,
                model: "GPT-5 Codex",
                limitID: "codex.primary",
                label: "5 小时额度",
                usedPercent: 28,
                resetTime: now.addingTimeInterval(3 * 3_600 + 45 * 60),
                windowDurationMinutes: 300,
                updatedAt: now
            ),
            QuotaStatus(
                id: "codex.weekly",
                provider: .codex,
                account: nil,
                model: "GPT-5 Codex",
                limitID: "codex.weekly",
                label: "周额度",
                usedPercent: 40,
                resetTime: now.addingTimeInterval(3 * 86_400 + 2 * 3_600),
                windowDurationMinutes: 10_080,
                updatedAt: now
            )
        ]
        return WidgetQuotaSnapshot(
            snapshot: ProviderSnapshot(
                provider: .codex,
                account: nil,
                plan: nil,
                model: "GPT-5 Codex",
                quotas: quotas,
                updatedAt: now
            )
        )
    }
}
