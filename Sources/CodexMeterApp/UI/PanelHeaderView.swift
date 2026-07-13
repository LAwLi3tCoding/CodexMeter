import AppKit
import CodexMeterCore
import SwiftUI

struct PanelHeaderView: View {
    let presentation: StatusPanelPresentation?
    let staleFailure: QuotaStoreFailure?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 11) {
                Image(nsImage: NSApplication.shared.applicationIconImage)
                    .resizable()
                    .interpolation(.high)
                    .frame(width: 34, height: 34)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 2) {
                    Text("CodexMeter")
                        .font(.title3.weight(.semibold))

                    Text("Codex 使用额度")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 12)

                if let plan = presentation?.planText {
                    Text(plan)
                        .font(.caption2.weight(.semibold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .foregroundStyle(.secondary)
                        .background(.quaternary, in: Capsule())
                }
            }

            Grid(alignment: .leading, horizontalSpacing: 18, verticalSpacing: 7) {
                GridRow {
                    MetadataLabel(
                        symbol: "person.crop.circle",
                        text: presentation?.accountText ?? "Codex 账号"
                    )
                    MetadataLabel(
                        symbol: "cpu",
                        text: presentation?.modelText ?? "Codex"
                    )
                }

                GridRow {
                    MetadataLabel(
                        symbol: "clock",
                        text: presentation?.updatedText ?? "尚未更新"
                    )
                    .gridCellColumns(2)
                }
            }

            if let staleFailure {
                Label {
                    Text("显示上次数据 · \(staleFailure.localizedDescription)")
                        .lineLimit(2)
                } icon: {
                    Image(systemName: "exclamationmark.arrow.triangle.2.circlepath")
                }
                .font(.caption)
                .foregroundStyle(.orange)
                .accessibilityLabel("额度数据可能已过期，\(staleFailure.localizedDescription)")
            }
        }
        .accessibilityElement(children: .contain)
    }
}

private struct MetadataLabel: View {
    let symbol: String
    let text: String

    var body: some View {
        Label(text, systemImage: symbol)
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}
