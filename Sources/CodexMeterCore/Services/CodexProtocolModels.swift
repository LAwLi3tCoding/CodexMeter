public struct CodexAccount: Codable, Equatable, Sendable {
    public let type: String
    public let email: String?
    public let planType: String?

    public init(type: String, email: String? = nil, planType: String? = nil) {
        self.type = type
        self.email = email
        self.planType = planType
    }
}

public struct CodexAccountResponse: Codable, Equatable, Sendable {
    public let account: CodexAccount?
    public let requiresOpenaiAuth: Bool

    public init(account: CodexAccount?, requiresOpenaiAuth: Bool) {
        self.account = account
        self.requiresOpenaiAuth = requiresOpenaiAuth
    }
}

public struct CodexRateLimitWindow: Codable, Equatable, Sendable {
    public let usedPercent: Double
    public let windowDurationMins: Int?
    public let resetsAt: Int?

    public init(
        usedPercent: Double,
        windowDurationMins: Int? = nil,
        resetsAt: Int? = nil
    ) {
        self.usedPercent = usedPercent
        self.windowDurationMins = windowDurationMins
        self.resetsAt = resetsAt
    }
}

public struct CodexRateLimitSnapshot: Codable, Equatable, Sendable {
    public let limitId: String
    public let limitName: String?
    public let primary: CodexRateLimitWindow?
    public let secondary: CodexRateLimitWindow?
    public let planType: String?

    public init(
        limitId: String,
        limitName: String? = nil,
        primary: CodexRateLimitWindow? = nil,
        secondary: CodexRateLimitWindow? = nil,
        planType: String? = nil
    ) {
        self.limitId = limitId
        self.limitName = limitName
        self.primary = primary
        self.secondary = secondary
        self.planType = planType
    }
}

public struct CodexRateLimitsResponse: Codable, Equatable, Sendable {
    public let rateLimits: CodexRateLimitSnapshot
    public let rateLimitsByLimitId: [String: CodexRateLimitSnapshot]?

    public init(
        rateLimits: CodexRateLimitSnapshot,
        rateLimitsByLimitId: [String: CodexRateLimitSnapshot]? = nil
    ) {
        self.rateLimits = rateLimits
        self.rateLimitsByLimitId = rateLimitsByLimitId
    }

    public static let empty = CodexRateLimitsResponse(
        rateLimits: CodexRateLimitSnapshot(limitId: "codex")
    )
}

public struct CodexEffectiveConfig: Codable, Equatable, Sendable {
    public let model: String?

    public init(model: String?) {
        self.model = model
    }
}

public struct CodexConfigResponse: Codable, Equatable, Sendable {
    public let config: CodexEffectiveConfig

    public init(config: CodexEffectiveConfig) {
        self.config = config
    }
}
