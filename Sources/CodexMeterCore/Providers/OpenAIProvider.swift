public struct OpenAIProvider: QuotaProvider, Sendable {
    public init() {}

    public func fetchSnapshot() async throws -> ProviderSnapshot {
        throw ProviderError.notConfigured
    }
}
