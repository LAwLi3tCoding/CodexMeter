import Foundation
import CodexMeterCore

let widgetSnapshot: [HarnessTest] = [
    HarnessTest(
        suite: "widget",
        name: "Widget snapshot converts domain data and round trips privately",
        body: testWidgetSnapshotRoundTrip
    ),
    HarnessTest(
        suite: "widget",
        name: "Widget snapshot dates use milliseconds since 1970",
        body: testWidgetSnapshotDateEncoding
    ),
    HarnessTest(
        suite: "widget",
        name: "Widget snapshot rejects missing malformed and future data",
        body: testWidgetSnapshotRejectsUnreadableData
    ),
    HarnessTest(
        suite: "widget",
        name: "Failed widget snapshot writes preserve valid data",
        body: testFailedWidgetSnapshotWritePreservesValidData
    )
]

private func testWidgetSnapshotRoundTrip() throws {
    let suiteName = "CodexMeterTests.widget.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName)!
    defer { defaults.removePersistentDomain(forName: suiteName) }
    let providerSnapshot = makeWidgetProviderSnapshot()

    let widget = WidgetQuotaSnapshot(snapshot: providerSnapshot)

    expectEqual(WidgetConfiguration.appGroupID, "group.com.codexmeter.CodexMeter")
    expectEqual(WidgetConfiguration.snapshotKey, "widget.quota.snapshot.v1")
    expectEqual(WidgetConfiguration.widgetKind, "com.codexmeter.CodexMeter.quota-widget")
    expectEqual(widget.schemaVersion, WidgetQuotaSnapshot.currentSchemaVersion)
    expectEqual(widget.plan, "plus")
    expectEqual(widget.model, "gpt-5.5")
    expectEqual(widget.updatedAt, providerSnapshot.updatedAt)
    expectEqual(widget.quotas.count, 2)
    expectEqual(widget.quotas.first?.remainingPercent, 72)
    expectEqual(widget.quotas.first?.windowDurationMinutes, 300)

    let store = WidgetSnapshotStore(defaults: defaults)
    try store.write(widget)

    expectEqual(store.read(), widget)
    let encoded = defaults.data(forKey: WidgetConfiguration.snapshotKey)!
    let encodedText = String(decoding: encoded, as: UTF8.self)
    expectEqual(encodedText.contains("developer@example.com"), false)
    expectEqual(encodedText.contains("account"), false)
}

private func testWidgetSnapshotDateEncoding() throws {
    let suiteName = "CodexMeterTests.widget.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName)!
    defer { defaults.removePersistentDomain(forName: suiteName) }
    let widget = WidgetQuotaSnapshot(snapshot: makeWidgetProviderSnapshot())

    try WidgetSnapshotStore(defaults: defaults).write(widget)

    let data = defaults.data(forKey: WidgetConfiguration.snapshotKey)!
    let object = try JSONSerialization.jsonObject(with: data) as! [String: Any]
    let quotas = object["quotas"] as! [[String: Any]]
    expectEqual(object["updatedAt"] as? Double, 1_730_900_123_000)
    expectEqual(quotas.first?["resetTime"] as? Double, 1_730_914_523_000)
}

private func testWidgetSnapshotRejectsUnreadableData() throws {
    let suiteName = "CodexMeterTests.widget.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName)!
    defer { defaults.removePersistentDomain(forName: suiteName) }
    let store = WidgetSnapshotStore(defaults: defaults)

    expectNil(store.read())

    defaults.set(Data("not-json".utf8), forKey: WidgetConfiguration.snapshotKey)
    expectNil(store.read())

    var futureObject = try JSONSerialization.jsonObject(
        with: encodedWidgetSnapshot(makeWidgetProviderSnapshot())
    ) as! [String: Any]
    futureObject["schemaVersion"] = WidgetQuotaSnapshot.currentSchemaVersion + 1
    defaults.set(
        try JSONSerialization.data(withJSONObject: futureObject),
        forKey: WidgetConfiguration.snapshotKey
    )
    expectNil(store.read())
}

private func testFailedWidgetSnapshotWritePreservesValidData() throws {
    let suiteName = "CodexMeterTests.widget.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName)!
    defer { defaults.removePersistentDomain(forName: suiteName) }
    let store = WidgetSnapshotStore(defaults: defaults)
    let valid = WidgetQuotaSnapshot(snapshot: makeWidgetProviderSnapshot())
    try store.write(valid)

    let invalid = WidgetQuotaSnapshot(
        snapshot: makeWidgetProviderSnapshot(primaryUsedPercent: .nan)
    )
    var didThrow = false
    do {
        try store.write(invalid)
    } catch {
        didThrow = true
    }

    expectEqual(didThrow, true)
    expectEqual(store.read(), valid)
}

private func encodedWidgetSnapshot(_ snapshot: ProviderSnapshot) throws -> Data {
    let suiteName = "CodexMeterTests.widget.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName)!
    defer { defaults.removePersistentDomain(forName: suiteName) }
    try WidgetSnapshotStore(defaults: defaults).write(
        WidgetQuotaSnapshot(snapshot: snapshot)
    )
    return defaults.data(forKey: WidgetConfiguration.snapshotKey)!
}

private func makeWidgetProviderSnapshot(
    primaryUsedPercent: Double = 28
) -> ProviderSnapshot {
    let updatedAt = Date(timeIntervalSince1970: 1_730_900_123)
    return ProviderSnapshot(
        provider: .codex,
        account: "developer@example.com",
        plan: "plus",
        model: "gpt-5.5",
        quotas: [
            QuotaStatus(
                id: "codex.primary",
                provider: .codex,
                account: "developer@example.com",
                model: "gpt-5.5",
                limitID: "codex",
                label: "5 小时额度",
                usedPercent: primaryUsedPercent,
                resetTime: updatedAt.addingTimeInterval(14_400),
                windowDurationMinutes: 300,
                updatedAt: updatedAt
            ),
            QuotaStatus(
                id: "codex.secondary",
                provider: .codex,
                account: "developer@example.com",
                model: "gpt-5.5",
                limitID: "codex",
                label: "周额度",
                usedPercent: 55,
                resetTime: nil,
                windowDurationMinutes: 10_080,
                updatedAt: updatedAt
            )
        ],
        updatedAt: updatedAt
    )
}
