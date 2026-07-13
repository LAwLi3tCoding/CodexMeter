import Foundation

public enum WidgetConfiguration {
    public static let appGroupID = "group.com.codexmeter.CodexMeter"
    public static let snapshotKey = "widget.quota.snapshot.v1"
    public static let widgetKind = "com.codexmeter.CodexMeter.quota-widget"
}

public struct WidgetQuotaItem: Codable, Equatable, Sendable {
    public let id: String
    public let label: String
    public let model: String
    public let remainingPercent: Double
    public let resetTime: Date?
    public let windowDurationMinutes: Int?

    public init(
        id: String,
        label: String,
        model: String,
        remainingPercent: Double,
        resetTime: Date?,
        windowDurationMinutes: Int?
    ) {
        self.id = id
        self.label = label
        self.model = model
        self.remainingPercent = remainingPercent
        self.resetTime = resetTime
        self.windowDurationMinutes = windowDurationMinutes
    }
}

public struct WidgetQuotaSnapshot: Codable, Equatable, Sendable {
    public static let currentSchemaVersion = 1

    public let schemaVersion: Int
    public let provider: ProviderKind
    public let model: String
    public let quotas: [WidgetQuotaItem]
    public let updatedAt: Date

    public init(snapshot: ProviderSnapshot) {
        schemaVersion = Self.currentSchemaVersion
        provider = snapshot.provider
        model = snapshot.model
        quotas = snapshot.quotas.map { quota in
            WidgetQuotaItem(
                id: quota.id,
                label: quota.label,
                model: quota.model,
                remainingPercent: quota.percentage,
                resetTime: quota.resetTime,
                windowDurationMinutes: quota.windowDurationMinutes
            )
        }
        updatedAt = snapshot.updatedAt
    }
}
