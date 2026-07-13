import Foundation

public enum ProviderAccountKind: String, Equatable, Sendable {
    case chatGPT
    case apiKey
    case unknown
}

public struct ProviderSnapshot: Equatable, Sendable {
    public let provider: ProviderKind
    public let account: String?
    public let accountKind: ProviderAccountKind
    public let plan: String?
    public let model: String
    public let quotas: [QuotaStatus]
    public let updatedAt: Date

    public init(
        provider: ProviderKind,
        account: String?,
        accountKind: ProviderAccountKind = .unknown,
        plan: String?,
        model: String,
        quotas: [QuotaStatus],
        updatedAt: Date
    ) {
        self.provider = provider
        self.account = account
        self.accountKind = accountKind
        self.plan = plan
        self.model = model
        self.quotas = quotas
        self.updatedAt = updatedAt
    }
}
