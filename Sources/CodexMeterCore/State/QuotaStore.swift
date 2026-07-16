import Combine
import Foundation

public enum QuotaStoreFailure: Error, Equatable, Sendable {
    case cliNotFound
    case notAuthenticated
    case noQuota
    case incompatibleProtocol
    case serviceUnavailable
}

extension QuotaStoreFailure: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .cliNotFound:
            return "Codex CLI was not found. Install Codex first."
        case .notAuthenticated:
            return "Codex is not signed in. Sign in with the Codex CLI first."
        case .noQuota:
            return "The current account did not return any displayable Codex quota."
        case .incompatibleProtocol:
            return "The Codex CLI protocol has changed. Update CodexMeter or the Codex CLI."
        case .serviceUnavailable:
            return "Codex quota could not be refreshed. Try again later."
        }
    }
}

public protocol WidgetSnapshotPublishing: Sendable {
    func publish(_ snapshot: ProviderSnapshot) async
}

private struct NoOpWidgetSnapshotPublisher: WidgetSnapshotPublishing {
    func publish(_ snapshot: ProviderSnapshot) async {}
}

@MainActor
public final class QuotaStore: ObservableObject {
    @Published public private(set) var snapshot: ProviderSnapshot?
    @Published public private(set) var isRefreshing = false
    @Published public private(set) var failure: QuotaStoreFailure?
    @Published public private(set) var autoRefreshEnabled: Bool

    private let provider: any QuotaProvider
    private let settings: SettingsStore
    private let notifier: any NotificationDelivering
    private let notificationPolicy: NotificationPolicy
    private let widgetPublisher: any WidgetSnapshotPublishing
    private var autoRefreshTask: Task<Void, Never>?
    private var refreshTask: Task<Void, Never>?
    private var refreshGeneration = 0
    private var hasStarted = false

    public init(
        provider: any QuotaProvider,
        settings: SettingsStore = SettingsStore(),
        notifier: any NotificationDelivering = NotificationService(),
        notificationPolicy: NotificationPolicy = NotificationPolicy(),
        widgetPublisher: (any WidgetSnapshotPublishing)? = nil
    ) {
        self.provider = provider
        self.settings = settings
        self.notifier = notifier
        self.notificationPolicy = notificationPolicy
        self.widgetPublisher = widgetPublisher ?? NoOpWidgetSnapshotPublisher()
        self.autoRefreshEnabled = settings.autoRefreshEnabled
    }

    deinit {
        autoRefreshTask?.cancel()
        refreshTask?.cancel()
    }

    public func start() {
        guard !hasStarted else { return }
        hasStarted = true

        _ = beginRefreshIfNeeded()
        restartAutoRefreshLoop()
    }

    public func stop() async {
        hasStarted = false
        autoRefreshTask?.cancel()
        autoRefreshTask = nil

        let activeRefresh = refreshTask
        activeRefresh?.cancel()
        await provider.shutdown()
        await activeRefresh?.value
        refreshTask = nil
    }

    public func setAutoRefreshEnabled(_ enabled: Bool) {
        guard autoRefreshEnabled != enabled else { return }
        autoRefreshEnabled = enabled
        settings.autoRefreshEnabled = enabled
        restartAutoRefreshLoop()
    }

    public func refresh() async {
        let task = beginRefreshIfNeeded()
        await task.value
    }

    private func beginRefreshIfNeeded() -> Task<Void, Never> {
        if let refreshTask {
            return refreshTask
        }

        refreshGeneration &+= 1
        let generation = refreshGeneration
        let task = Task { [weak self] in
            guard let self else { return }
            await self.performRefresh()
            self.finishRefresh(generation: generation)
        }
        refreshTask = task
        return task
    }

    private func finishRefresh(generation: Int) {
        guard refreshGeneration == generation else { return }
        refreshTask = nil
    }

    private func performRefresh() async {
        guard !Task.isCancelled else { return }
        isRefreshing = true
        defer { isRefreshing = false }

        do {
            let newSnapshot = try await provider.fetchSnapshot()
            guard !Task.isCancelled else { return }
            snapshot = newSnapshot
            failure = nil
            await widgetPublisher.publish(newSnapshot)
            await evaluateNotifications(for: newSnapshot)
        } catch {
            guard !Task.isCancelled else { return }
            failure = Self.classify(error)
        }
    }

    private func restartAutoRefreshLoop() {
        autoRefreshTask?.cancel()
        autoRefreshTask = nil

        guard hasStarted, autoRefreshEnabled else { return }
        let interval = settings.refreshInterval
        autoRefreshTask = Task { [weak self] in
            while !Task.isCancelled {
                let nanoseconds = UInt64(interval * 1_000_000_000)
                do {
                    try await Task.sleep(nanoseconds: nanoseconds)
                } catch {
                    return
                }
                guard !Task.isCancelled else { return }
                await self?.refresh()
            }
        }
    }

    private func evaluateNotifications(for snapshot: ProviderSnapshot) async {
        for quota in snapshot.quotas {
            let cycleKey = NotificationCycleKey.make(for: quota)
            var state = settings.notificationState(for: cycleKey)

            let recoveredWithoutResetTime = quota.resetTime == nil
                && state.lastRemainingPercentage.map {
                    quota.percentage >= $0 + 5
                } == true

            if recoveredWithoutResetTime {
                state.sentThresholds.removeAll()
                state.lastRemainingPercentage = quota.percentage
                settings.setNotificationState(state, for: cycleKey)
                continue
            }

            let evaluation = notificationPolicy.evaluate(
                previousRemainingPercentage: state.lastRemainingPercentage,
                remainingPercentage: quota.percentage,
                previouslySent: state.sentThresholds
            )

            if let decision = evaluation.decision,
               await notifier.deliver(decision) {
                state.sentThresholds = evaluation.reachedThresholds
            }

            state.lastRemainingPercentage = quota.percentage
            settings.setNotificationState(state, for: cycleKey)
        }
    }

    private static func classify(_ error: Error) -> QuotaStoreFailure {
        if let providerError = error as? ProviderError {
            switch providerError {
            case .notAuthenticated:
                return .notAuthenticated
            case .executableNotFound:
                return .cliNotFound
            case .noQuota:
                return .noQuota
            case .notConfigured, .serviceUnavailable:
                return .serviceUnavailable
            }
        }

        if let clientError = error as? CodexAppServerClientError,
           clientError == .invalidResponse {
            return .incompatibleProtocol
        }

        if error is CodexExecutableLocatorError {
            return .cliNotFound
        }

        return .serviceUnavailable
    }
}
