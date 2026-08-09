import AppKit
import CodexMeterCore
import SwiftUI

struct PanelFooterView: View {
    @ObservedObject var store: QuotaStore
    @State private var showsNetworkSettings = false

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
                showsNetworkSettings.toggle()
            } label: {
                Label("Network", systemImage: "network")
            }
            .buttonStyle(.borderless)
            .controlSize(.small)
            .foregroundStyle(.secondary)
            .help("Configure an optional local proxy")
            .popover(isPresented: $showsNetworkSettings) {
                LocalProxySettingsView(store: store)
            }

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

private struct LocalProxySettingsView: View {
    @ObservedObject var store: QuotaStore
    @State private var draft = ""
    @State private var statusMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Local Proxy")
                    .font(.headline)
                Text("Used only by Codex App Server requests. Loopback HTTP(S) URLs with an explicit port are accepted.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            TextField("http://127.0.0.1:7897", text: $draft)
                .textFieldStyle(.roundedBorder)

            if let statusMessage {
                Text(statusMessage)
                    .font(.caption)
                    .foregroundStyle(statusMessage.hasPrefix("Invalid") ? .orange : .secondary)
            }

            HStack {
                Button("Clear") {
                    draft = ""
                    _ = store.setLocalProxyURL(nil)
                    statusMessage = "Proxy disabled. Restart CodexMeter to apply."
                }
                Spacer()
                Button("Save") {
                    if store.setLocalProxyURL(draft) {
                        draft = store.localProxyURL ?? ""
                        statusMessage = "Saved. Restart CodexMeter to apply."
                    } else {
                        statusMessage = "Invalid URL. Use localhost, 127.0.0.1, or ::1 with a port."
                    }
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(16)
        .frame(width: 330)
        .onAppear {
            draft = store.localProxyURL ?? ""
        }
    }
}
