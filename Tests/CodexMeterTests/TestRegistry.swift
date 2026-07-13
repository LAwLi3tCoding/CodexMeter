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
        + widgetSnapshot
        + widgetPresentation

    static let live = codexLiveSmoke
}
