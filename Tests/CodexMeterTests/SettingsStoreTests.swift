import Foundation
import CodexMeterCore

let settingsStore: [HarnessTest] = [
    HarnessTest(
        suite: "storage",
        name: "Settings defaults and notification state persist",
        body: testSettingsPersistence
    ),
    HarnessTest(
        suite: "storage",
        name: "Notification state keeps the most recently touched cycles",
        body: testNotificationStateEviction
    )
]

private func testSettingsPersistence() {
    let suiteName = "CodexMeterTests.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName)!
    defer { defaults.removePersistentDomain(forName: suiteName) }

    let store = SettingsStore(defaults: defaults)
    expectEqual(store.autoRefreshEnabled, true)
    expectEqual(store.refreshInterval, 60)

    store.autoRefreshEnabled = false
    store.refreshInterval = 120
    store.setSentThresholds([50, 30], for: "cycle")

    let reloaded = SettingsStore(defaults: defaults)
    expectEqual(reloaded.autoRefreshEnabled, false)
    expectEqual(reloaded.refreshInterval, 120)
    expectEqual(reloaded.sentThresholds(for: "cycle"), Set([50, 30]))
}

private func testNotificationStateEviction() {
    let suiteName = "CodexMeterTests.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName)!
    defer { defaults.removePersistentDomain(forName: suiteName) }
    let store = SettingsStore(defaults: defaults)

    for index in 0..<256 {
        store.setSentThresholds([50], for: "cycle-\(index)")
    }
    store.setSentThresholds([30], for: "000-current")

    expectEqual(store.sentThresholds(for: "000-current"), Set([30]))
}
