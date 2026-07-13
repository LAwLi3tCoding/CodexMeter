import AppKit
import CodexMeterCore
import SwiftUI

struct StatusPanelView: View {
    @ObservedObject var store: QuotaStore

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            PanelHeaderView(
                presentation: store.snapshot.map {
                    StatusPanelPresentation(snapshot: $0)
                }
            )

            statusContent

            PanelFooterView(
                store: store,
                updatedText: store.snapshot.map {
                    StatusPanelPresentation(snapshot: $0).updatedText
                }
            )
        }
        .padding(16)
        .frame(width: 360)
    }

    @ViewBuilder
    private var statusContent: some View {
        if let snapshot = store.snapshot {
            if let failure = store.failure {
                StaleDataBanner(failure: failure)
            }

            if snapshot.quotas.isEmpty {
                StatusMessageView(
                    symbol: "gauge.with.dots.needle.0percent",
                    title: "暂无额度数据",
                    message: "Codex CLI 没有返回可展示的额度窗口。"
                )
            } else {
                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(
                            snapshot.quotas.map {
                                QuotaCardPresentation(quota: $0)
                            },
                            id: \.id
                        ) { presentation in
                            QuotaCardView(presentation: presentation)
                        }
                    }
                }
                .frame(maxHeight: 410)
            }
        } else if store.isRefreshing {
            StatusMessageView(
                symbol: "bolt.horizontal.circle",
                title: "正在读取 Codex 额度",
                message: "通过本机 Codex CLI 安全获取当前状态。",
                showsProgress: true
            )
        } else if let failure = store.failure {
            StatusMessageView(
                symbol: "exclamationmark.triangle.fill",
                title: "无法读取额度",
                message: failure.localizedDescription,
                role: .error
            )
        } else {
            StatusMessageView(
                symbol: "gauge.with.dots.needle.33percent",
                title: "等待额度数据",
                message: "CodexMeter 将自动刷新。"
            )
        }
    }
}

private struct StatusMessageView: View {
    enum Role {
        case neutral
        case error
    }

    let symbol: String
    let title: String
    let message: String
    var showsProgress = false
    var role: Role = .neutral

    var body: some View {
        VStack(spacing: 9) {
            if showsProgress {
                ProgressView()
                    .controlSize(.small)
            } else {
                Image(systemName: symbol)
                    .font(.system(size: 26, weight: .medium))
                    .foregroundStyle(role == .error ? Color.orange : Color.secondary)
            }

            Text(title)
                .font(.headline)
            Text(message)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, minHeight: 126)
        .padding(.horizontal, 18)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
}

private struct StaleDataBanner: View {
    let failure: QuotaStoreFailure

    var body: some View {
        Label {
            Text("显示上次数据 · \(failure.localizedDescription)")
                .lineLimit(2)
        } icon: {
            Image(systemName: "exclamationmark.arrow.triangle.2.circlepath")
        }
        .font(.caption)
        .foregroundStyle(.orange)
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 9))
    }
}
