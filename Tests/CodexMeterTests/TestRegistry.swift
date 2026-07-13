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

    static let live = codexLiveSmoke
}
