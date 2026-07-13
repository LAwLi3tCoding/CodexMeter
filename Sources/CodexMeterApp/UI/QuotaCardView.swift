import AppKit
import CodexMeterCore
import SwiftUI

struct QuotaCardView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityDifferentiateWithoutColor) private var differentiateWithoutColor

    let presentation: QuotaCardPresentation

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(presentation.title)
                        .font(.headline)
                        .lineLimit(1)

                    Text(presentation.modelText)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 4)

                Image(systemName: statusSymbol)
                    .font(.caption.weight(.semibold))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(accentColor)
                    .help(statusDescription)
                    .accessibilityLabel(statusDescription)
            }

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(presentation.percentageText)
                    .font(.system(size: 32, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(accentColor)

                Text("剩余")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            SegmentedQuotaGauge(
                progress: presentation.progress,
                tint: accentColor
            )
                .animation(
                    reduceMotion ? nil : .easeInOut(duration: 0.22),
                    value: presentation.progress
                )

            HStack(spacing: 8) {
                Label(presentation.usedText, systemImage: "chart.bar.fill")
                Spacer(minLength: 4)
                Label(presentation.countdownText, systemImage: "clock")
            }
            .font(.caption)
            .monospacedDigit()

            Text(presentation.resetText)
                .font(.caption2)
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(13)
        .frame(maxWidth: .infinity, minHeight: 164, alignment: .topLeading)
        .background {
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
                .overlay {
                    RoundedRectangle(cornerRadius: 15, style: .continuous)
                        .fill(accentColor.opacity(0.055))
                }
        }
        .overlay {
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(presentation.accessibilityLabel)
        .accessibilityValue(statusDescription)
    }

    private var accentColor: Color {
        switch presentation.level {
        case .healthy:
            return .green
        case .warning:
            return .orange
        case .critical:
            return .red
        }
    }

    private var statusSymbol: String {
        switch presentation.level {
        case .healthy:
            return differentiateWithoutColor ? "checkmark.circle.fill" : "circle.fill"
        case .warning:
            return "exclamationmark.circle.fill"
        case .critical:
            return "exclamationmark.triangle.fill"
        }
    }

    private var statusDescription: String {
        switch presentation.level {
        case .healthy:
            return "额度充足"
        case .warning:
            return "额度低于一半"
        case .critical:
            return "额度即将用尽"
        }
    }
}

private struct SegmentedQuotaGauge: View {
    let progress: Double
    let tint: Color

    private let segmentCount = 10

    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<segmentCount, id: \.self) { index in
                GeometryReader { proxy in
                    Capsule()
                        .fill(Color.primary.opacity(0.09))
                        .overlay(alignment: .leading) {
                            Capsule()
                                .fill(tint)
                                .frame(width: proxy.size.width * fillAmount(for: index))
                        }
                }
                .frame(height: 7)
            }
        }
        .frame(height: 7)
        .accessibilityHidden(true)
    }

    private func fillAmount(for index: Int) -> Double {
        min(max((progress * Double(segmentCount)) - Double(index), 0), 1)
    }
}
