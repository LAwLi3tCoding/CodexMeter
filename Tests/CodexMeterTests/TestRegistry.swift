enum TestRegistry {
    static let all: [HarnessTest] =
        quotaStatus
        + quotaFormatter
        + menuBarPresentation
        + codexProtocolDecoding
        + codexExecutableLocator
        + codexAppServerClient
        + codexProvider
        + notificationPolicy
        + settingsStore
        + quotaStore
        + quotaCardPresentation
        + usageDashboard
        + widgetSnapshot
        + widgetPresentation

    static let live = codexLiveSmoke
    static let liveUsage = codexLiveUsageSmoke
}
