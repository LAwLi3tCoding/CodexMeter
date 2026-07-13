public protocol QuotaProvider: Sendable {
    func fetchSnapshot() async throws -> ProviderSnapshot
    func shutdown() async
}

public extension QuotaProvider {
    func shutdown() async {}
}

public enum ProviderError: Error, Equatable, Sendable {
    case notAuthenticated
    case executableNotFound
    case noQuota
    case notConfigured
    case serviceUnavailable
}
