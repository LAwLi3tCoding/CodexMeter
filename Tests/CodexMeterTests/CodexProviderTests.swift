import Foundation
import CodexMeterCore

let codexProvider: [HarnessTest] = [
    HarnessTest(
        suite: "provider",
        name: "Provider maps every multi-bucket window",
        body: testMultiBucketMapping
    ),
    HarnessTest(
        suite: "provider",
        name: "Provider falls back to the single bucket",
        body: testSingleBucketFallback
    ),
    HarnessTest(
        suite: "provider",
        name: "Provider rejects an unauthenticated account",
        body: testUnauthenticatedAccount
    ),
    HarnessTest(
        suite: "provider",
        name: "Provider keeps quotas when config lookup fails",
        body: testConfigFailureFallback
    )
]

private func testMultiBucketMapping() async throws {
    let now = Date(timeIntervalSince1970: 1_730_900_000)
    let client = StubCodexClient(
        accountResponse: CodexAccountResponse(
            account: CodexAccount(type: "chatgpt", email: "developer@example.com", planType: "pro"),
            requiresOpenaiAuth: true
        ),
        rateLimitsResponse: CodexRateLimitsResponse(
            rateLimits: CodexRateLimitSnapshot(
                limitId: "fallback",
                primary: CodexRateLimitWindow(usedPercent: 99, windowDurationMins: 300, resetsAt: 1),
                planType: "pro"
            ),
            rateLimitsByLimitId: [
                "codex": CodexRateLimitSnapshot(
                    limitId: "codex",
                    primary: CodexRateLimitWindow(usedPercent: 25, windowDurationMins: 300, resetsAt: 1_730_947_200),
                    secondary: CodexRateLimitWindow(usedPercent: 40, windowDurationMins: 10_080, resetsAt: 1_731_552_000),
                    planType: "pro"
                ),
                "codex_spark": CodexRateLimitSnapshot(
                    limitId: "codex_spark",
                    limitName: "GPT-5.3-Codex-Spark",
                    primary: CodexRateLimitWindow(usedPercent: 5, windowDurationMins: 10_080, resetsAt: 1_731_552_000),
                    planType: "pro"
                )
            ]
        ),
        configResponse: CodexConfigResponse(config: CodexEffectiveConfig(model: "gpt-5.5"))
    )

    let snapshot = try await CodexProvider(client: client, now: { now }).fetchSnapshot()

    expectEqual(snapshot.account, "developer@example.com")
    expectEqual(snapshot.accountKind, .chatGPT)
    expectEqual(snapshot.plan, "pro")
    expectEqual(snapshot.model, "gpt-5.5")
    expectEqual(snapshot.quotas.map(\.id), ["codex.primary", "codex.secondary", "codex_spark.primary"])
    expectEqual(snapshot.quotas.map(\.percentage), [75, 60, 95])
    expectEqual(snapshot.quotas.map(\.label), ["5 小时额度", "周额度", "周额度"])
    expectEqual(snapshot.quotas.last?.model, "GPT-5.3-Codex-Spark")
    expectEqual(snapshot.updatedAt, now)
}

private func testSingleBucketFallback() async throws {
    let client = StubCodexClient(
        accountResponse: CodexAccountResponse(account: CodexAccount(type: "apiKey"), requiresOpenaiAuth: true),
        rateLimitsResponse: CodexRateLimitsResponse(
            rateLimits: CodexRateLimitSnapshot(
                limitId: "codex",
                primary: CodexRateLimitWindow(usedPercent: 10, windowDurationMins: 300)
            ),
            rateLimitsByLimitId: nil
        ),
        configResponse: CodexConfigResponse(config: CodexEffectiveConfig(model: nil))
    )

    let snapshot = try await CodexProvider(client: client).fetchSnapshot()

    expectEqual(snapshot.model, "Codex")
    expectEqual(snapshot.accountKind, .apiKey)
    expectEqual(snapshot.quotas.count, 1)
    expectEqual(snapshot.quotas.first?.percentage, 90)
}

private func testUnauthenticatedAccount() async {
    let client = StubCodexClient(
        accountResponse: CodexAccountResponse(account: nil, requiresOpenaiAuth: true),
        rateLimitsResponse: .empty,
        configResponse: CodexConfigResponse(config: CodexEffectiveConfig(model: nil))
    )

    do {
        _ = try await CodexProvider(client: client).fetchSnapshot()
        TestRecorder.record("expected provider to reject unauthenticated account")
    } catch let error as ProviderError {
        expectEqual(error, .notAuthenticated)
    } catch {
        TestRecorder.record("unexpected error: \(error)")
    }
}

private func testConfigFailureFallback() async throws {
    let client = FailingConfigCodexClient(
        accountResponse: CodexAccountResponse(
            account: CodexAccount(type: "chatgpt", planType: "plus"),
            requiresOpenaiAuth: true
        ),
        rateLimitsResponse: CodexRateLimitsResponse(
            rateLimits: CodexRateLimitSnapshot(
                limitId: "codex",
                primary: CodexRateLimitWindow(
                    usedPercent: 20,
                    windowDurationMins: 300
                )
            )
        )
    )

    let snapshot = try await CodexProvider(client: client).fetchSnapshot()

    expectEqual(snapshot.model, "Codex")
    expectEqual(snapshot.quotas.first?.percentage, 80)
}

private struct StubCodexClient: CodexClientProtocol {
    let accountResponse: CodexAccountResponse
    let rateLimitsResponse: CodexRateLimitsResponse
    let configResponse: CodexConfigResponse

    func account() async throws -> CodexAccountResponse { accountResponse }
    func rateLimits() async throws -> CodexRateLimitsResponse { rateLimitsResponse }
    func effectiveConfig() async throws -> CodexConfigResponse { configResponse }
}

private struct FailingConfigCodexClient: CodexClientProtocol {
    let accountResponse: CodexAccountResponse
    let rateLimitsResponse: CodexRateLimitsResponse

    func account() async throws -> CodexAccountResponse { accountResponse }
    func rateLimits() async throws -> CodexRateLimitsResponse { rateLimitsResponse }
    func effectiveConfig() async throws -> CodexConfigResponse {
        throw CodexAppServerClientError.invalidResponse
    }
}
