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

                    Text("Codex Usage Dashboard")
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

            HStack(alignment: .top, spacing: 8) {
                MetadataItem(
                    label: "ACCOUNT",
                    value: presentation?.accountText ?? "Codex 账号"
                )
                MetadataItem(
                    label: "MODEL",
                    value: presentation?.modelText ?? "Codex"
                )
                MetadataItem(
                    label: "UPDATED",
                    value: presentation?.updatedText ?? "尚未更新"
                )
            }
            .padding(10)
            .background(Color.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 10, style: .continuous))

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

private struct MetadataItem: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(.tertiary)
                .tracking(0.6)

            Text(value)
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .help(value)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(label), \(value)")
    }
}
