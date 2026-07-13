import AppKit
import CodexMeterCore
import SwiftUI

struct StatusPanelView: View {
    @ObservedObject var store: QuotaStore

    private let quotaColumns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible())
    ]

    var body: some View {
        let presentation = panelPresentation

        VStack(spacing: 0) {
            PanelHeaderView(
                presentation: presentation,
                staleFailure: store.snapshot == nil ? nil : store.failure
            )
            .padding(16)

            Divider()

            statusContent(presentation: presentation)
                .padding(14)

            Divider()

            PanelFooterView(store: store)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
        }
        .frame(width: 448)
        .fixedSize(horizontal: false, vertical: true)
    }

    private var panelPresentation: StatusPanelPresentation? {
        store.snapshot.map { StatusPanelPresentation(snapshot: $0) }
    }

    @ViewBuilder
    private func statusContent(
        presentation: StatusPanelPresentation?
    ) -> some View {
        if let presentation {
            if presentation.quotaCards.isEmpty {
                StatusMessageView(
                    symbol: "gauge.with.dots.needle.0percent",
                    title: "暂无额度数据",
                    message: "Codex CLI 没有返回可展示的额度窗口。"
                )
            } else {
                LazyVGrid(
                    columns: quotaColumns,
                    alignment: .leading,
                    spacing: 10
                ) {
                    ForEach(presentation.quotaCards, id: \.id) { card in
                        QuotaCardView(presentation: card)
                    }
                }
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
        VStack(spacing: 10) {
            if showsProgress {
                ProgressView()
                    .controlSize(.small)
            } else {
                Image(systemName: symbol)
                    .font(.system(size: 26, weight: .medium))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(role == .error ? Color.orange : Color.secondary)
            }

            VStack(spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 132)
        .padding(.horizontal, 20)
        .background {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
        }
    }
}
