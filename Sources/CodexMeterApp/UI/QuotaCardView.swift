import CodexMeterCore
import SwiftUI

struct QuotaCardView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let presentation: QuotaCardPresentation

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(presentation.title)
                        .font(.headline)
                    Text(presentation.modelText)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                Text(presentation.percentageText)
                    .font(.system(.title2, design: .rounded, weight: .bold))
                    .foregroundStyle(accentColor)
            }

            ProgressView(value: presentation.progress)
                .progressViewStyle(.linear)
                .tint(accentColor)
                .animation(
                    reduceMotion ? nil : .easeInOut(duration: 0.25),
                    value: presentation.progress
                )

            HStack {
                Label(presentation.remainingText, systemImage: "chart.bar.fill")
                Spacer()
                Label(presentation.countdownText, systemImage: "clock")
            }
            .font(.caption.weight(.medium))

            Text(presentation.resetText)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(accentColor.opacity(0.18), lineWidth: 1)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(presentation.accessibilityLabel)
    }

    private var accentColor: Color {
        switch presentation.level {
        case .healthy:
            return .green
        case .warning:
            return .yellow
        case .low:
            return .orange
        case .critical:
            return .red
        }
    }
}
