import AppKit
import CodexMeterCore
import SwiftUI

struct PanelFooterView: View {
    @ObservedObject var store: QuotaStore

    var body: some View {
        HStack(spacing: 12) {
            Toggle(
                isOn: Binding(
                    get: { store.autoRefreshEnabled },
                    set: store.setAutoRefreshEnabled
                )
            ) {
                VStack(alignment: .leading, spacing: 1) {
                    Text("Auto Refresh")
                    Text("Background updates")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .toggleStyle(.switch)
            .controlSize(.small)

            Spacer(minLength: 8)

            Button {
                Task { await store.refresh() }
            } label: {
                if store.isRefreshing {
                    ProgressView()
                        .controlSize(.small)
                        .frame(width: 14, height: 14)
                } else {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .disabled(store.isRefreshing)
            .help("Refresh Codex quota now")
            .accessibilityLabel(store.isRefreshing ? "Refreshing" : "Refresh Codex quota now")

            Button {
                Task {
                    await store.stop()
                    NSApplication.shared.terminate(nil)
                }
            } label: {
                Label("Quit", systemImage: "power")
            }
            .buttonStyle(.borderless)
            .controlSize(.small)
            .foregroundStyle(.secondary)
            .keyboardShortcut("q")
            .help("Quit CodexMeter")
        }
    }
}
