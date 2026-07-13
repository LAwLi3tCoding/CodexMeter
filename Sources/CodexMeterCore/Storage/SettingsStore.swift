import Foundation

public struct NotificationCycleState: Codable, Equatable, Sendable {
    public var sentThresholds: Set<Int>
    public var lastRemainingPercentage: Double?
    fileprivate var touchOrder: UInt64

    public init(
        sentThresholds: Set<Int> = [],
        lastRemainingPercentage: Double? = nil
    ) {
        self.sentThresholds = sentThresholds
        self.lastRemainingPercentage = lastRemainingPercentage
        self.touchOrder = 0
    }
}

public final class SettingsStore: @unchecked Sendable {
    private struct NotificationArchive: Codable {
        var nextTouchOrder: UInt64
        var cycles: [String: NotificationCycleState]

        static let empty = NotificationArchive(nextTouchOrder: 0, cycles: [:])
    }

    private enum Key {
        static let autoRefreshEnabled = "autoRefreshEnabled"
        static let refreshInterval = "refreshInterval"
        static let sentThresholds = "sentNotificationThresholds"
    }

    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public var autoRefreshEnabled: Bool {
        get {
            guard defaults.object(forKey: Key.autoRefreshEnabled) != nil else {
                return true
            }
            return defaults.bool(forKey: Key.autoRefreshEnabled)
        }
        set {
            defaults.set(newValue, forKey: Key.autoRefreshEnabled)
        }
    }

    public var refreshInterval: TimeInterval {
        get {
            let stored = defaults.double(forKey: Key.refreshInterval)
            return stored > 0 ? stored : 60
        }
        set {
            defaults.set(max(15, newValue), forKey: Key.refreshInterval)
        }
    }

    public func sentThresholds(for cycleKey: String) -> Set<Int> {
        notificationState(for: cycleKey).sentThresholds
    }

    public func setSentThresholds(_ thresholds: Set<Int>, for cycleKey: String) {
        var state = notificationState(for: cycleKey)
        state.sentThresholds = thresholds
        setNotificationState(state, for: cycleKey)
    }

    public func notificationState(for cycleKey: String) -> NotificationCycleState {
        loadArchive().cycles[cycleKey] ?? NotificationCycleState()
    }

    public func setNotificationState(
        _ state: NotificationCycleState,
        for cycleKey: String
    ) {
        var archive = loadArchive()
        archive.nextTouchOrder &+= 1

        var touchedState = state
        touchedState.touchOrder = archive.nextTouchOrder
        archive.cycles[cycleKey] = touchedState

        if archive.cycles.count > 256 {
            archive.cycles = Dictionary(
                uniqueKeysWithValues: archive.cycles
                    .sorted { $0.value.touchOrder > $1.value.touchOrder }
                    .prefix(256)
                    .map { ($0.key, $0.value) }
            )
        }

        if let data = try? JSONEncoder().encode(archive) {
            defaults.set(data, forKey: Key.sentThresholds)
        }
    }

    private func loadArchive() -> NotificationArchive {
        guard let data = defaults.data(forKey: Key.sentThresholds) else {
            return .empty
        }

        if let archive = try? JSONDecoder().decode(NotificationArchive.self, from: data) {
            return archive
        }

        if let legacy = try? JSONDecoder().decode([String: [Int]].self, from: data) {
            var archive = NotificationArchive.empty
            for (key, thresholds) in legacy.sorted(by: { $0.key < $1.key }) {
                archive.nextTouchOrder &+= 1
                var state = NotificationCycleState(sentThresholds: Set(thresholds))
                state.touchOrder = archive.nextTouchOrder
                archive.cycles[key] = state
            }
            return archive
        }

        return .empty
    }
}
