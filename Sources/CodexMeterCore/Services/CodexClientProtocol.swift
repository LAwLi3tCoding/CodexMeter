public protocol CodexClientProtocol: Sendable {
    func account() async throws -> CodexAccountResponse
    func rateLimits() async throws -> CodexRateLimitsResponse
    func effectiveConfig() async throws -> CodexConfigResponse
    func tokenUsage() async throws -> CodexTokenUsageResponse
    func shutdown() async
}

public extension CodexClientProtocol {
    func tokenUsage() async throws -> CodexTokenUsageResponse { .empty }
    func shutdown() async {}
}
