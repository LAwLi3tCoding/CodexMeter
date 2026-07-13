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
        do {
            let client = try CodexAppServerClient()
            return QuotaStore(provider: CodexProvider(client: client))
        } catch {
            return QuotaStore(provider: MissingCodexProvider())
        }
    }
}

private struct MissingCodexProvider: QuotaProvider {
    func fetchSnapshot() async throws -> ProviderSnapshot {
        throw ProviderError.executableNotFound
    }
}
