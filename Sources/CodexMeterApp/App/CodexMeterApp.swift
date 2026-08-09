import AppKit
import SwiftUI
import CodexMeterCore

@main
struct CodexMeterApp: App {
    @StateObject private var store: QuotaStore

    init() {
        _ = NSApplication.shared.setActivationPolicy(.accessory)

        let store = Self.makeStore()
        store.start()
        _store = StateObject(wrappedValue: store)
    }

    var body: some Scene {
        MenuBarExtra {
            StatusPanelView(store: store)
        } label: {
            MenuBarLabel(
                presentation: MenuBarPresentation(
                    quotas: store.snapshot?.quotas ?? []
                )
            )
        }
        .menuBarExtraStyle(.window)
    }

    @MainActor
    private static func makeStore() -> QuotaStore {
        let widgetPublisher = AppWidgetSnapshotPublisher()
        let settings = SettingsStore()
        let cachedSnapshot = WidgetSnapshotStore.sharedApplicationSupport()?
            .read()
            .map(ProviderSnapshot.init(cachedWidgetSnapshot:))

        do {
            let processEnvironment = settings.localProxyURL.map { proxyURL in
                [
                    "HTTP_PROXY": proxyURL,
                    "HTTPS_PROXY": proxyURL,
                    "http_proxy": proxyURL,
                    "https_proxy": proxyURL
                ]
            } ?? [:]
            let quotaClient = try CodexAppServerClient(
                processEnvironment: processEnvironment
            )
            let usageClient = try CodexAppServerClient(
                processEnvironment: processEnvironment
            )
            let modelUsageReader: any ModelUsageReading
            if let databaseURL = SQLiteThreadModelUsageReader.defaultDatabaseURL() {
                modelUsageReader = SQLiteThreadModelUsageReader(databaseURL: databaseURL)
            } else {
                modelUsageReader = UnavailableModelUsageReader()
            }
            return QuotaStore(
                provider: CodexProvider(client: quotaClient),
                usageProvider: CodexUsageProvider(
                    client: usageClient,
                    modelUsageReader: modelUsageReader
                ),
                initialSnapshot: cachedSnapshot,
                settings: settings,
                widgetPublisher: widgetPublisher
            )
        } catch {
            return QuotaStore(
                provider: MissingCodexProvider(),
                initialSnapshot: cachedSnapshot,
                settings: settings,
                widgetPublisher: widgetPublisher
            )
        }
    }
}

private struct MissingCodexProvider: QuotaProvider {
    func fetchSnapshot() async throws -> ProviderSnapshot {
        throw ProviderError.executableNotFound
    }
}
