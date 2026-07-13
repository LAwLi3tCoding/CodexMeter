import Foundation

public struct CodexProvider: QuotaProvider, Sendable {
    private let client: any CodexClientProtocol
    private let now: @Sendable () -> Date

    public init(
        client: any CodexClientProtocol,
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.client = client
        self.now = now
    }

    public func fetchSnapshot() async throws -> ProviderSnapshot {
        let accountResponse = try await client.account()
        guard !accountResponse.requiresOpenaiAuth || accountResponse.account != nil else {
            throw ProviderError.notAuthenticated
        }

        async let limitsRequest = client.rateLimits()
        async let configRequest = client.effectiveConfig()

        let limitsResponse: CodexRateLimitsResponse
        do {
            limitsResponse = try await limitsRequest
        } catch {
            _ = try? await configRequest
            throw error
        }
        let configResponse = try? await configRequest

        let updatedAt = now()
        let configuredModel = configResponse?.config.model ?? "Codex"
        let account = accountResponse.account?.email
        let snapshots = normalizedSnapshots(from: limitsResponse)
        let quotas = snapshots.flatMap { key, snapshot in
            quotaStatuses(
                key: key,
                snapshot: snapshot,
                account: account,
                configuredModel: configuredModel,
                updatedAt: updatedAt
            )
        }

        guard !quotas.isEmpty else {
            throw ProviderError.noQuota
        }

        return ProviderSnapshot(
            provider: .codex,
            account: account,
            accountKind: accountKind(for: accountResponse.account?.type),
            plan: resolvedPlan(
                from: limitsResponse,
                accountPlan: accountResponse.account?.planType
            ),
            model: configuredModel,
            quotas: quotas,
            updatedAt: updatedAt
        )
    }

    public func shutdown() async {
        await client.shutdown()
    }

    private func accountKind(for type: String?) -> ProviderAccountKind {
        switch type?.lowercased() {
        case "chatgpt":
            return .chatGPT
        case "apikey", "api_key", "api-key":
            return .apiKey
        default:
            return .unknown
        }
    }

    private func normalizedSnapshots(
        from response: CodexRateLimitsResponse
    ) -> [(key: String, snapshot: CodexRateLimitSnapshot)] {
        if let buckets = response.rateLimitsByLimitId, !buckets.isEmpty {
            return buckets.keys.sorted().compactMap { key in
                buckets[key].map { (key, $0) }
            }
        }

        return [(response.rateLimits.limitId, response.rateLimits)]
    }

    private func resolvedPlan(
        from response: CodexRateLimitsResponse,
        accountPlan: String?
    ) -> String? {
        if let rootPlan = normalizedPlan(response.rateLimits.planType) {
            return rootPlan
        }

        let buckets = response.rateLimitsByLimitId ?? [:]
        let canonicalPlan = buckets
            .sorted { $0.key < $1.key }
            .first { key, snapshot in
                key.lowercased() == "codex" || snapshot.limitId.lowercased() == "codex"
            }
            .flatMap { normalizedPlan($0.value.planType) }
        if let canonicalPlan {
            return canonicalPlan
        }

        let otherPlans = Set(buckets.values.compactMap { normalizedPlan($0.planType) })
        if otherPlans.count == 1 {
            return otherPlans.first
        }

        return normalizedPlan(accountPlan)
    }

    private func normalizedPlan(_ plan: String?) -> String? {
        guard let plan else { return nil }
        let normalized = plan.trimmingCharacters(in: .whitespacesAndNewlines)
        return normalized.isEmpty ? nil : normalized
    }

    private func quotaStatuses(
        key: String,
        snapshot: CodexRateLimitSnapshot,
        account: String?,
        configuredModel: String,
        updatedAt: Date
    ) -> [QuotaStatus] {
        let model = snapshot.limitName ?? configuredModel
        let windows: [(name: String, value: CodexRateLimitWindow?)] = [
            ("primary", snapshot.primary),
            ("secondary", snapshot.secondary)
        ]

        return windows.compactMap { name, window in
            guard let window else { return nil }

            return QuotaStatus(
                id: "\(key).\(name)",
                provider: .codex,
                account: account,
                model: model,
                limitID: key,
                label: QuotaFormatter.windowLabel(minutes: window.windowDurationMins),
                usedPercent: window.usedPercent,
                resetTime: window.resetsAt.map { Date(timeIntervalSince1970: TimeInterval($0)) },
                windowDurationMinutes: window.windowDurationMins,
                updatedAt: updatedAt
            )
        }
    }
}
