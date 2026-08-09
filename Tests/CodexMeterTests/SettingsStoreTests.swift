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
    expectNil(store.localProxyURL)

    store.autoRefreshEnabled = false
    store.refreshInterval = 120
    store.localProxyURL = " http://127.0.0.1:7897 "
    store.setSentThresholds([50, 30], for: "cycle")

    let reloaded = SettingsStore(defaults: defaults)
    expectEqual(reloaded.autoRefreshEnabled, false)
    expectEqual(reloaded.refreshInterval, 120)
    expectEqual(reloaded.localProxyURL, "http://127.0.0.1:7897")
    expectEqual(reloaded.sentThresholds(for: "cycle"), Set([50, 30]))

    expectEqual(reloaded.updateLocalProxyURL("https://proxy.example.com:443"), false)
    expectEqual(reloaded.localProxyURL, "http://127.0.0.1:7897")

    expectEqual(reloaded.updateLocalProxyURL("http://user:secret@127.0.0.1:7897"), false)
    expectEqual(reloaded.localProxyURL, "http://127.0.0.1:7897")

    expectEqual(reloaded.updateLocalProxyURL("http://localhost"), false)
    expectEqual(reloaded.localProxyURL, "http://127.0.0.1:7897")

    expectEqual(reloaded.updateLocalProxyURL("socks5://127.0.0.1:7897"), false)
    expectEqual(reloaded.localProxyURL, "http://127.0.0.1:7897")

    expectEqual(reloaded.updateLocalProxyURL("http://[::1]:7897"), true)
    expectEqual(reloaded.localProxyURL, "http://[::1]:7897")

    expectEqual(reloaded.updateLocalProxyURL(nil), true)
    expectNil(reloaded.localProxyURL)
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
