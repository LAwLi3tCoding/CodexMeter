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
    ),
    HarnessTest(
        suite: "widget",
        name: "Widget snapshot file store round trips atomically",
        body: testWidgetSnapshotFileStore
    )
]

private func testWidgetSnapshotRoundTrip() throws {
    let suiteName = "CodexMeterTests.widget.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName)!
    defer { defaults.removePersistentDomain(forName: suiteName) }
    let providerSnapshot = makeWidgetProviderSnapshot()

    let widget = WidgetQuotaSnapshot(snapshot: providerSnapshot)

    expectEqual(WidgetConfiguration.snapshotKey, "widget.quota.snapshot.v1")
    expectEqual(WidgetConfiguration.snapshotFileName, "quota-snapshot-v1.json")
    expectEqual(WidgetConfiguration.widgetKind, "com.codexmeter.CodexMeter.quota-widget")
    expectEqual(widget.schemaVersion, WidgetQuotaSnapshot.currentSchemaVersion)
    expectEqual(widget.model, "gpt-5.5")
    expectEqual(widget.updatedAt, providerSnapshot.updatedAt)
    expectEqual(widget.quotas.count, 2)
    expectEqual(widget.quotas.first?.remainingPercent, 72)
    expectEqual(widget.quotas.first?.windowDurationMinutes, 300)

    let store = WidgetSnapshotStore(defaults: defaults)
    try store.write(widget)

    expectEqual(store.read(), widget)
    let encoded = defaults.data(forKey: WidgetConfiguration.snapshotKey)!
    let object = try JSONSerialization.jsonObject(with: encoded) as! [String: Any]
    expectEqual(
        Set(object.keys),
        Set(["schemaVersion", "provider", "model", "updatedAt", "quotas"])
    )
    expectEqual(object["provider"] as? String, "codex")

    let quotas = object["quotas"] as! [[String: Any]]
    expectEqual(
        Set(quotas[0].keys),
        Set([
            "id",
            "label",
            "model",
            "remainingPercent",
            "resetTime",
            "windowDurationMinutes"
        ])
    )
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

private func testWidgetSnapshotFileStore() throws {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("CodexMeterWidgetTests-\(UUID().uuidString)")
    let fileURL = directory.appendingPathComponent("quota-snapshot.json")
    defer { try? FileManager.default.removeItem(at: directory) }

    let store = WidgetSnapshotStore(fileURL: fileURL)
    let valid = WidgetQuotaSnapshot(snapshot: makeWidgetProviderSnapshot())

    expectNil(store.read())
    try store.write(valid)

    expectEqual(store.read(), valid)
    expectEqual(FileManager.default.fileExists(atPath: fileURL.path), true)
    let permissions = try FileManager.default.attributesOfItem(atPath: fileURL.path)[
        .posixPermissions
    ] as? NSNumber
    expectEqual(permissions?.intValue, 0o600)
    let directoryPermissions = try FileManager.default.attributesOfItem(
        atPath: directory.path
    )[.posixPermissions] as? NSNumber
    expectEqual(directoryPermissions?.intValue, 0o700)

    let replacement = WidgetQuotaSnapshot(
        snapshot: makeWidgetProviderSnapshot(primaryUsedPercent: 45)
    )
    try store.write(replacement)
    expectEqual(store.read(), replacement)

    let injectedHomeURL = directory.appendingPathComponent("InjectedHome")
    let applicationSupportStore = WidgetSnapshotStore.applicationSupport(
        homeDirectoryURL: injectedHomeURL
    )
    try applicationSupportStore.write(valid)
    let injectedSnapshotURL = injectedHomeURL
        .appendingPathComponent("Library/Application Support/CodexMeter")
        .appendingPathComponent(WidgetConfiguration.snapshotFileName)
    expectEqual(FileManager.default.fileExists(atPath: injectedSnapshotURL.path), true)
    expectEqual(applicationSupportStore.read(), valid)

    let rejectingStore = WidgetSnapshotStore(
        fileURL: fileURL,
        fileManager: RejectingTemporaryFileAttributesFileManager()
    )
    var rejectedWriteDidThrow = false
    do {
        try rejectingStore.write(valid)
    } catch {
        rejectedWriteDidThrow = true
    }
    expectEqual(rejectedWriteDidThrow, true)
    expectEqual(store.read(), replacement)
    let temporaryFiles = try FileManager.default.contentsOfDirectory(
        at: directory,
        includingPropertiesForKeys: nil
    ).filter { $0.lastPathComponent.hasSuffix(".tmp") }
    expectEqual(temporaryFiles.isEmpty, true)

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
    expectEqual(store.read(), replacement)
}

private final class RejectingTemporaryFileAttributesFileManager: FileManager, @unchecked Sendable {
    override func setAttributes(
        _ attributes: [FileAttributeKey: Any],
        ofItemAtPath path: String
    ) throws {
        if path.hasSuffix(".tmp") {
            throw CocoaError(.fileWriteNoPermission)
        }
        try super.setAttributes(attributes, ofItemAtPath: path)
    }
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
                label: "5-hour quota",
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
                label: "Weekly quota",
                usedPercent: 55,
                resetTime: nil,
                windowDurationMinutes: 10_080,
                updatedAt: updatedAt
            )
        ],
        updatedAt: updatedAt
    )
}
