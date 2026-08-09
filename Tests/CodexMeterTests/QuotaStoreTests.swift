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
        name: "First refresh failure retains the cached launch snapshot",
        body: testCachedLaunchSnapshotRetention
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
    ),
    HarnessTest(
        suite: "store",
        name: "Panel-facing failures use English descriptions",
        body: testFailureDescriptions
    ),
    HarnessTest(
        suite: "store",
        name: "Refresh publishes quota and usage independently",
        body: testRefreshPublishesUsage
    ),
    HarnessTest(
        suite: "store",
        name: "Usage failure does not hide refreshed quota",
        body: testUsageFailureDoesNotHideQuota
    ),
    HarnessTest(
        suite: "store",
        name: "Quota failure does not block refreshed usage",
        body: testQuotaFailureDoesNotBlockUsage
    ),
    HarnessTest(
        suite: "store",
        name: "Quota and usage providers start in the same refresh",
        body: testQuotaAndUsageStartConcurrently
    ),
    HarnessTest(
        suite: "store",
        name: "Usage refresh failure retains data and marks it stale",
        body: testUsageFailureMarksRetainedDataStale
    )
]

private func testFailureDescriptions() {
    expectEqual(QuotaStoreFailure.cliNotFound.errorDescription, "Codex CLI was not found. Install Codex first.")
    expectEqual(QuotaStoreFailure.notAuthenticated.errorDescription, "Codex is not signed in. Sign in with the Codex CLI first.")
    expectEqual(QuotaStoreFailure.noQuota.errorDescription, "The current account did not return any displayable Codex quota.")
    expectEqual(QuotaStoreFailure.incompatibleProtocol.errorDescription, "The Codex CLI protocol has changed. Update CodexMeter or the Codex CLI.")
    expectEqual(QuotaStoreFailure.serviceUnavailable.errorDescription, "Codex quota could not be refreshed. Try again later.")
    expectEqual(UsageStoreFailure.unavailable.errorDescription, "Usage history is temporarily unavailable.")
}

@MainActor
private func testCachedLaunchSnapshotRetention() async {
    let cached = makeSnapshot(remainingPercentage: 73)
    let store = QuotaStore(
        provider: StubQuotaProvider(results: [.failure(ProviderError.serviceUnavailable)]),
        initialSnapshot: cached,
        settings: makeSettingsStore(),
        notifier: RecordingNotifier()
    )

    await store.refresh()

    expectEqual(store.snapshot, cached)
    expectEqual(store.failure, .serviceUnavailable)
}

@MainActor
private func testRefreshPublishesUsage() async {
    let snapshot = makeSnapshot(remainingPercentage: 80)
    let usage = makeUsageSnapshot(currentModel: snapshot.model)
    let store = QuotaStore(
        provider: StubQuotaProvider(results: [.success(snapshot)]),
        usageProvider: StubUsageProvider(results: [.success(usage)]),
        settings: makeSettingsStore(),
        notifier: RecordingNotifier()
    )

    await store.refresh()

    expectEqual(store.snapshot, snapshot)
    expectEqual(store.usageSnapshot, usage)
    expectNil(store.usageFailure)
}

@MainActor
private func testUsageFailureDoesNotHideQuota() async {
    let snapshot = makeSnapshot(remainingPercentage: 80)
    let store = QuotaStore(
        provider: StubQuotaProvider(results: [.success(snapshot)]),
        usageProvider: StubUsageProvider(results: [.failure(ProviderError.serviceUnavailable)]),
        settings: makeSettingsStore(),
        notifier: RecordingNotifier()
    )

    await store.refresh()

    expectEqual(store.snapshot, snapshot)
    expectNil(store.failure)
    expectNil(store.usageSnapshot)
    expectEqual(store.usageFailure, .unavailable)
}

@MainActor
private func testQuotaFailureDoesNotBlockUsage() async {
    let usage = makeUsageSnapshot(currentModel: "gpt-5.6-sol")
    let store = QuotaStore(
        provider: StubQuotaProvider(results: [.failure(ProviderError.serviceUnavailable)]),
        usageProvider: StubUsageProvider(results: [.success(usage)]),
        settings: makeSettingsStore(),
        notifier: RecordingNotifier()
    )

    await store.refresh()

    expectNil(store.snapshot)
    expectEqual(store.failure, .serviceUnavailable)
    expectEqual(store.usageSnapshot, usage)
    expectNil(store.usageFailure)
}

@MainActor
private func testQuotaAndUsageStartConcurrently() async {
    let probe = RefreshOverlapProbe()
    let snapshot = makeSnapshot(remainingPercentage: 80)
    let usage = makeUsageSnapshot(currentModel: snapshot.model)
    let store = QuotaStore(
        provider: GatedQuotaProvider(snapshot: snapshot, probe: probe),
        usageProvider: ProbedUsageProvider(snapshot: usage, probe: probe),
        settings: makeSettingsStore(),
        notifier: RecordingNotifier()
    )

    let refresh = Task { await store.refresh() }
    while await !probe.quotaDidStart() {
        await Task.yield()
    }
    for _ in 0..<100 {
        if await probe.usageDidStart() { break }
        await Task.yield()
    }
    let overlapped = await probe.usageDidStart()
    await probe.releaseQuota()
    await refresh.value

    expectEqual(overlapped, true)
}

@MainActor
private func testUsageFailureMarksRetainedDataStale() async {
    let snapshot = makeSnapshot(remainingPercentage: 80)
    let usage = makeUsageSnapshot(currentModel: snapshot.model)
    let store = QuotaStore(
        provider: StubQuotaProvider(results: [.success(snapshot), .success(snapshot)]),
        usageProvider: StubUsageProvider(results: [
            .success(usage),
            .failure(ProviderError.serviceUnavailable)
        ]),
        settings: makeSettingsStore(),
        notifier: RecordingNotifier()
    )

    await store.refresh()
    await store.refresh()

    expectEqual(store.usageSnapshot, usage)
    expectEqual(store.usageFailure, .unavailable)
}

@MainActor
private func testRefreshSuccess() async throws {
    let snapshot = makeSnapshot(remainingPercentage: 25)
    let provider = StubQuotaProvider(results: [.success(snapshot)])
    let notifier = RecordingNotifier()
    let widgetPublisher = RecordingWidgetSnapshotPublisher()
    let store = QuotaStore(
        provider: provider,
        settings: makeSettingsStore(),
        notifier: notifier,
        widgetPublisher: widgetPublisher
    )

    await store.refresh()

    expectEqual(store.snapshot, snapshot)
    expectNil(store.failure)
    expectEqual(await notifier.deliveredThresholds(), [30])
    expectEqual(await widgetPublisher.snapshots(), [snapshot])
}

@MainActor
private func testStaleSnapshotRetention() async throws {
    let snapshot = makeSnapshot(remainingPercentage: 80)
    let provider = StubQuotaProvider(results: [
        .success(snapshot),
        .failure(ProviderError.serviceUnavailable)
    ])
    let widgetPublisher = RecordingWidgetSnapshotPublisher()
    let store = QuotaStore(
        provider: provider,
        settings: makeSettingsStore(),
        notifier: RecordingNotifier(),
        widgetPublisher: widgetPublisher
    )

    await store.refresh()
    await store.refresh()

    expectEqual(store.snapshot, snapshot)
    expectEqual(store.failure, .serviceUnavailable)
    expectEqual(await widgetPublisher.snapshots(), [snapshot])
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
    let usageProvider = StubUsageProvider(results: [])
    let store = QuotaStore(
        provider: provider,
        usageProvider: usageProvider,
        settings: makeSettingsStore(),
        notifier: RecordingNotifier()
    )

    store.start()
    try? await Task.sleep(nanoseconds: 10_000_000)
    await store.stop()
    try? await Task.sleep(nanoseconds: 80_000_000)

    expectNil(store.snapshot)
    expectEqual(await provider.didShutdown(), true)
    expectEqual(await usageProvider.didShutdown(), true)
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

private actor StubUsageProvider: UsageProviding {
    private var results: [Result<UsageSnapshot, Error>]
    private var shutdownCalled = false

    init(results: [Result<UsageSnapshot, Error>]) {
        self.results = results
    }

    func fetchUsage() async throws -> UsageSnapshot {
        guard !results.isEmpty else { throw ProviderError.serviceUnavailable }
        return try results.removeFirst().get()
    }

    func shutdown() async {
        shutdownCalled = true
    }

    func didShutdown() -> Bool {
        shutdownCalled
    }
}

private actor RefreshOverlapProbe {
    private var quotaStarted = false
    private var usageStarted = false
    private var quotaReleased = false
    private var quotaContinuation: CheckedContinuation<Void, Never>?

    func waitForQuotaRelease() async {
        quotaStarted = true
        guard !quotaReleased else { return }
        await withCheckedContinuation { continuation in
            quotaContinuation = continuation
        }
    }

    func markUsageStarted() {
        usageStarted = true
    }

    func quotaDidStart() -> Bool { quotaStarted }
    func usageDidStart() -> Bool { usageStarted }

    func releaseQuota() {
        quotaReleased = true
        quotaContinuation?.resume()
        quotaContinuation = nil
    }
}

private actor GatedQuotaProvider: QuotaProvider {
    let snapshot: ProviderSnapshot
    let probe: RefreshOverlapProbe

    init(snapshot: ProviderSnapshot, probe: RefreshOverlapProbe) {
        self.snapshot = snapshot
        self.probe = probe
    }

    func fetchSnapshot() async throws -> ProviderSnapshot {
        await probe.waitForQuotaRelease()
        return snapshot
    }
}

private actor ProbedUsageProvider: UsageProviding {
    let snapshot: UsageSnapshot
    let probe: RefreshOverlapProbe

    init(snapshot: UsageSnapshot, probe: RefreshOverlapProbe) {
        self.snapshot = snapshot
        self.probe = probe
    }

    func fetchUsage() async throws -> UsageSnapshot {
        await probe.markUsageStarted()
        return snapshot
    }
}

private actor RecordingWidgetSnapshotPublisher: WidgetSnapshotPublishing {
    private var publishedSnapshots: [ProviderSnapshot] = []

    func publish(_ snapshot: ProviderSnapshot) async {
        publishedSnapshots.append(snapshot)
    }

    func snapshots() -> [ProviderSnapshot] {
        publishedSnapshots
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
        label: "5-hour quota",
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

private func makeUsageSnapshot(currentModel: String) -> UsageSnapshot {
    let updatedAt = Date(timeIntervalSince1970: 500)
    let day = UsageDay(
        dayID: "1970-01-01",
        date: updatedAt,
        tokens: 100,
        estimatedCostUSD: 0.01
    )
    return UsageSnapshot(
        days: [day],
        todayTokens: 100,
        sevenDayTokens: 100,
        thirtyDayTokens: 100,
        todayEstimatedCostUSD: 0.01,
        sevenDayEstimatedCostUSD: 0.01,
        thirtyDayEstimatedCostUSD: 0.01,
        currentModel: currentModel,
        topModelSevenDays: currentModel,
        topModelSevenDayShare: 1,
        currentStreakDays: 1,
        peakDailyTokens: 100,
        sevenDayChange: nil,
        updatedAt: updatedAt
    )
}
