public protocol CodexClientProtocol: Sendable {
    func account() async throws -> CodexAccountResponse
    func rateLimits() async throws -> CodexRateLimitsResponse
    func effectiveConfig() async throws -> CodexConfigResponse
    func shutdown() async
}

public extension CodexClientProtocol {
    func shutdown() async {}
}
