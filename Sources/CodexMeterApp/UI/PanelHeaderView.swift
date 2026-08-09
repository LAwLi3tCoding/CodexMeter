import AppKit
import CodexMeterCore
import SwiftUI

struct PanelHeaderView: View {
    let presentation: StatusPanelPresentation?
    let staleFailure: QuotaStoreFailure?

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 9) {
                Image(nsImage: NSApplication.shared.applicationIconImage)
                    .resizable()
                    .interpolation(.high)
                    .frame(width: 27, height: 27)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 2) {
                    Text("CodexMeter")
                        .font(.headline.weight(.semibold))

                    Text("Codex Usage Dashboard")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 12)

                if let plan = presentation?.planText {
                    Text(plan)
                        .font(.caption2.weight(.semibold))
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .foregroundStyle(.secondary)
                        .background(.quaternary, in: Capsule())
                }
            }

            HStack(alignment: .top, spacing: 8) {
                MetadataItem(
                    label: "ACCOUNT",
                    value: presentation?.accountText ?? "Codex account"
                )
                MetadataItem(
                    label: "MODEL",
                    value: presentation?.modelText ?? "Codex"
                )
                MetadataItem(
                    label: "UPDATED",
                    value: presentation?.updatedText ?? "Not updated"
                )
            }
            .padding(.horizontal, 7)
            .padding(.vertical, 6)
            .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

            if let staleFailure {
                Label {
                    Text("Showing last update · \(staleFailure.localizedDescription)")
                        .lineLimit(2)
                } icon: {
                    Image(systemName: "exclamationmark.arrow.triangle.2.circlepath")
                }
                .font(.caption2)
                .foregroundStyle(.orange)
                .accessibilityLabel("Quota data may be stale. \(staleFailure.localizedDescription)")
            }
        }
        .accessibilityElement(children: .contain)
    }
}

private struct MetadataItem: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
                .tracking(0.6)

            Text(value)
                .font(.caption2.weight(.medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .help(value)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(label), \(value)")
    }
}
