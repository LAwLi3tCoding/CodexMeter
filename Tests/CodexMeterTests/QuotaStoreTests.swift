import Foundation
import CodexMeterCore

let quotaStore: [HarnessTest] = [
    HarnessTest(
        suite: "store",
        name: "Refresh publishes quota and sends one notification",
        body: testRefreshSuccess
    ),
    HarnessTest(
        suite: "store",
        name: "Refresh failure retains the last successful snapshot",
        body: testStaleSnapshotRetention
    ),
    HarnessTest(
        suite: "store",
        name: "Automatic refresh preference persists",
        body: testAutoRefreshPreference
    ),
    HarnessTest(
        suite: "store",
        name: "Missing reset time rearms notifications after quota recovery",
        body: testFallbackCycleRearming
    ),
    HarnessTest(
        suite: "store",
        name: "Quota recovery does not emit a threshold notification",
        body: testFallbackCycleRecoveryDoesNotNotify
    ),
    HarnessTest(
        suite: "store",
        name: "Stop cancels active refresh and shuts down its provider",
        body: testStopLifecycle
    )
]

@MainActor
private func testRefreshSuccess() async throws {
    let snapshot = makeSnapshot(remainingPercentage: 25)
    let provider = StubQuotaProvider(results: [.success(snapshot)])
    let notifier = RecordingNotifier()
    let store = QuotaStore(
        provider: provider,
        settings: makeSettingsStore(),
        notifier: notifier
    )

    await store.refresh()

    expectEqual(store.snapshot, snapshot)
    expectNil(store.failure)
    expectEqual(await notifier.deliveredThresholds(), [30])
}

@MainActor
private func testStaleSnapshotRetention() async throws {
    let snapshot = makeSnapshot(remainingPercentage: 80)
    let provider = StubQuotaProvider(results: [
        .success(snapshot),
        .failure(ProviderError.serviceUnavailable)
    ])
    let store = QuotaStore(
        provider: provider,
        settings: makeSettingsStore(),
        notifier: RecordingNotifier()
    )

    await store.refresh()
    await store.refresh()

    expectEqual(store.snapshot, snapshot)
    expectEqual(store.failure, .serviceUnavailable)
}

@MainActor
private func testAutoRefreshPreference() {
    let settings = makeSettingsStore()
    let store = QuotaStore(
        provider: StubQuotaProvider(results: []),
        settings: settings,
        notifier: RecordingNotifier()
    )

    store.setAutoRefreshEnabled(false)

    expectEqual(store.autoRefreshEnabled, false)
    expectEqual(settings.autoRefreshEnabled, false)
}

@MainActor
private func testFallbackCycleRearming() async {
    let provider = StubQuotaProvider(results: [
        .success(makeSnapshot(remainingPercentage: 25, resetTime: nil)),
        .success(makeSnapshot(remainingPercentage: 80, resetTime: nil)),
        .success(makeSnapshot(remainingPercentage: 25, resetTime: nil))
    ])
    let notifier = RecordingNotifier()
    let store = QuotaStore(
        provider: provider,
        settings: makeSettingsStore(),
        notifier: notifier
    )

    await store.refresh()
    await store.refresh()
    await store.refresh()

    expectEqual(await notifier.deliveredThresholds(), [30, 30])
}

@MainActor
private func testFallbackCycleRecoveryDoesNotNotify() async {
    let provider = StubQuotaProvider(results: [
        .success(makeSnapshot(remainingPercentage: 25, resetTime: nil)),
        .success(makeSnapshot(remainingPercentage: 35, resetTime: nil)),
        .success(makeSnapshot(remainingPercentage: 25, resetTime: nil))
    ])
    let notifier = RecordingNotifier()
    let store = QuotaStore(
        provider: provider,
        settings: makeSettingsStore(),
        notifier: notifier
    )

    await store.refresh()
    await store.refresh()
    expectEqual(await notifier.deliveredThresholds(), [30])

    await store.refresh()
    expectEqual(await notifier.deliveredThresholds(), [30, 30])
}

@MainActor
private func testStopLifecycle() async {
    let provider = SlowQuotaProvider(snapshot: makeSnapshot(remainingPercentage: 80))
    let store = QuotaStore(
        provider: provider,
        settings: makeSettingsStore(),
        notifier: RecordingNotifier()
    )

    store.start()
    try? await Task.sleep(nanoseconds: 10_000_000)
    await store.stop()
    try? await Task.sleep(nanoseconds: 80_000_000)

    expectNil(store.snapshot)
    expectEqual(await provider.didShutdown(), true)
}

private actor StubQuotaProvider: QuotaProvider {
    private var results: [Result<ProviderSnapshot, Error>]

    init(results: [Result<ProviderSnapshot, Error>]) {
        self.results = results
    }

    func fetchSnapshot() async throws -> ProviderSnapshot {
        guard !results.isEmpty else {
            throw ProviderError.serviceUnavailable
        }
        return try results.removeFirst().get()
    }
}

private actor RecordingNotifier: NotificationDelivering {
    private var thresholds: [Int] = []

    func deliver(_ decision: NotificationDecision) async -> Bool {
        thresholds.append(decision.threshold)
        return true
    }

    func deliveredThresholds() -> [Int] {
        thresholds
    }
}

private actor SlowQuotaProvider: QuotaProvider {
    private let snapshot: ProviderSnapshot
    private var shutdownCalled = false

    init(snapshot: ProviderSnapshot) {
        self.snapshot = snapshot
    }

    func fetchSnapshot() async throws -> ProviderSnapshot {
        try await Task.sleep(nanoseconds: 50_000_000)
        return snapshot
    }

    func shutdown() async {
        shutdownCalled = true
    }

    func didShutdown() -> Bool {
        shutdownCalled
    }
}

private func makeSettingsStore() -> SettingsStore {
    let suiteName = "CodexMeterTests.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName)!
    defaults.removePersistentDomain(forName: suiteName)
    return SettingsStore(defaults: defaults)
}

private func makeSnapshot(
    remainingPercentage: Double,
    resetTime: Date? = Date(timeIntervalSince1970: 1_000)
) -> ProviderSnapshot {
    let updatedAt = Date(timeIntervalSince1970: 500)
    let quota = QuotaStatus(
        id: "codex.primary",
        provider: .codex,
        account: "developer@example.com",
        model: "gpt-test",
        limitID: "codex",
        label: "5 小时额度",
        usedPercent: 100 - remainingPercentage,
        resetTime: resetTime,
        windowDurationMinutes: 300,
        updatedAt: updatedAt
    )
    return ProviderSnapshot(
        provider: .codex,
        account: quota.account,
        plan: "plus",
        model: quota.model,
        quotas: [quota],
        updatedAt: updatedAt
    )
}
