import AppKit
import CodexMeterCore
import SwiftUI

struct PanelFooterView: View {
    @ObservedObject var store: QuotaStore
    let updatedText: String?

    var body: some View {
        VStack(spacing: 10) {
            Divider()

            HStack {
                Toggle(
                    "自动刷新",
                    isOn: Binding(
                        get: { store.autoRefreshEnabled },
                        set: store.setAutoRefreshEnabled
                    )
                )
                .toggleStyle(.switch)
                .controlSize(.small)

                Spacer()

                Button {
                    Task { await store.refresh() }
                } label: {
                    if store.isRefreshing {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Label("刷新", systemImage: "arrow.clockwise")
                    }
                }
                .disabled(store.isRefreshing)
                .help("立即刷新 Codex 额度")
                .accessibilityLabel(store.isRefreshing ? "正在刷新" : "立即刷新 Codex 额度")
            }

            HStack {
                Text(updatedText ?? "尚未更新")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)

                Spacer()

                Button("退出") {
                    Task {
                        await store.stop()
                        NSApplication.shared.terminate(nil)
                    }
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .keyboardShortcut("q")
            }
        }
    }
}
