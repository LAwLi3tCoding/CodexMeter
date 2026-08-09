import AppKit
import CodexMeterCore
import SwiftUI

struct StatusPanelView: View {
    @ObservedObject var store: QuotaStore

    private let quotaColumns = [
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible())
    ]

    var body: some View {
        let presentation = panelPresentation

        VStack(spacing: 8) {
            PanelHeaderView(
                presentation: presentation,
                staleFailure: store.snapshot == nil ? nil : store.failure
            )
            .padding(9)
            .dashboardSurface(radius: 13)

            ScrollView {
                VStack(spacing: 8) {
                    statusContent(presentation: presentation)
                    usageContent
                }
            }
            .scrollIndicators(.never)
            .frame(maxHeight: 520)

            PanelFooterView(store: store)
                .padding(.horizontal, 9)
                .padding(.vertical, 7)
                .dashboardSurface(radius: 11)
        }
        .padding(8)
        .frame(width: 460)
        .background(Color(nsColor: .windowBackgroundColor))
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
                    title: "No quota data",
                    message: "Codex CLI did not return a displayable quota window."
                )
            } else {
                quotaGrid(presentation: presentation)
            }
        } else if store.isRefreshing {
            StatusMessageView(
                symbol: "bolt.horizontal.circle",
                title: "Reading Codex quota",
                message: "Securely reading current status from the local Codex CLI.",
                showsProgress: true
            )
        } else if let failure = store.failure {
            StatusMessageView(
                symbol: "exclamationmark.triangle.fill",
                title: "Unable to read quota",
                message: failure.localizedDescription,
                role: .error
            )
        } else {
            StatusMessageView(
                symbol: "gauge.with.dots.needle.33percent",
                title: "Waiting for quota data",
                message: "CodexMeter will refresh automatically."
            )
        }
    }

    @ViewBuilder
    private var usageContent: some View {
        if let usageSnapshot = store.usageSnapshot {
            UsageDashboardView(
                presentation: UsageDashboardPresentation(snapshot: usageSnapshot),
                isStale: store.usageFailure != nil
            )
        } else if store.usageFailure != nil {
            UsageStatusView(
                symbol: "chart.bar.xaxis",
                title: "Usage history unavailable",
                message: "Quota is current. Token history will retry on the next refresh."
            )
        } else if store.snapshot != nil || store.isRefreshing {
            UsageStatusView(
                symbol: "chart.bar.fill",
                title: "Building 30-day history",
                message: "Reading daily token totals and local model usage.",
                showsProgress: true
            )
        }
    }

    private func quotaGrid(
        presentation: StatusPanelPresentation
    ) -> some View {
        LazyVGrid(
            columns: quotaColumns,
            alignment: .leading,
            spacing: 8
        ) {
            ForEach(presentation.quotaCards, id: \.id) { card in
                QuotaCardView(presentation: card)
            }
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
        .frame(maxWidth: .infinity, minHeight: 112)
        .padding(.horizontal, 20)
        .dashboardSurface(radius: 14)
    }
}

private struct UsageStatusView: View {
    let symbol: String
    let title: String
    let message: String
    var showsProgress = false

    var body: some View {
        HStack(spacing: 12) {
            if showsProgress {
                ProgressView()
                    .controlSize(.small)
                    .frame(width: 22)
            } else {
                Image(systemName: symbol)
                    .font(.title3)
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.secondary)
                    .frame(width: 22)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(13)
        .dashboardSurface(radius: 14)
    }
}

extension View {
    fileprivate func dashboardSurface(radius: CGFloat) -> some View {
        background {
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
        }
        .overlay {
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
        }
    }
}
