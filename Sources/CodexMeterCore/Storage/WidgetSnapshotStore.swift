import Foundation

public final class WidgetSnapshotStore: @unchecked Sendable {
    private let defaults: UserDefaults

    public init(defaults: UserDefaults) {
        self.defaults = defaults
    }

    public func read() -> WidgetQuotaSnapshot? {
        guard
            let data = defaults.data(forKey: WidgetConfiguration.snapshotKey),
            let snapshot = try? Self.decoder.decode(WidgetQuotaSnapshot.self, from: data),
            snapshot.schemaVersion == WidgetQuotaSnapshot.currentSchemaVersion
        else {
            return nil
        }

        return snapshot
    }

    public func write(_ snapshot: WidgetQuotaSnapshot) throws {
        let data = try Self.encoder.encode(snapshot)
        defaults.set(data, forKey: WidgetConfiguration.snapshotKey)
    }

    private static var encoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .millisecondsSince1970
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }

    private static var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .millisecondsSince1970
        return decoder
    }
}
