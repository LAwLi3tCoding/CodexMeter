import AppKit
import CodexMeterCore
import SwiftUI

struct PanelFooterView: View {
    @ObservedObject var store: QuotaStore

    var body: some View {
        HStack(spacing: 12) {
            Toggle(
                "自动刷新",
                isOn: Binding(
                    get: { store.autoRefreshEnabled },
                    set: store.setAutoRefreshEnabled
                )
            )
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
                    Label("刷新", systemImage: "arrow.clockwise")
                }
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .disabled(store.isRefreshing)
            .help("立即刷新 Codex 额度")
            .accessibilityLabel(store.isRefreshing ? "正在刷新" : "立即刷新 Codex 额度")

            Button {
                Task {
                    await store.stop()
                    NSApplication.shared.terminate(nil)
                }
            } label: {
                Label("退出", systemImage: "power")
            }
            .buttonStyle(.borderless)
            .controlSize(.small)
            .foregroundStyle(.secondary)
            .keyboardShortcut("q")
            .help("退出 CodexMeter")
        }
    }
}
