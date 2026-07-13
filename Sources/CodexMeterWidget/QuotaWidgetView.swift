import AppKit
import SwiftUI
import WidgetKit
import CodexMeterCore

struct QuotaWidgetView: View {
    let entry: QuotaWidgetEntry

    @Environment(\.widgetFamily) private var family

    var body: some View {
        Group {
            if let snapshot = entry.snapshot {
                let presentation = WidgetQuotaPresentation(
                    snapshot: snapshot,
                    now: entry.date
                )
                if presentation.quotas.isEmpty {
                    WidgetEmptyState()
                } else if family == .systemMedium {
                    MediumQuotaWidget(presentation: presentation)
                } else {
                    SmallQuotaWidget(presentation: presentation)
                }
            } else {
                WidgetEmptyState()
            }
        }
        .padding(16)
        .codexWidgetBackground()
    }
}

private struct SmallQuotaWidget: View {
    let presentation: WidgetQuotaPresentation

    var body: some View {
        let quota = presentation.quotas[0]

        VStack(alignment: .leading, spacing: 8) {
            WidgetHeader(
                model: nil,
                isStale: presentation.isStale
            )

            Spacer(minLength: 0)

            Text(quota.percentageText)
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(quota.level.widgetColor)

            Text(quota.label)
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)

            SegmentedQuotaBar(
                fillAmounts: quota.segmentFillAmounts,
                color: quota.level.widgetColor
            )

            HStack(spacing: 5) {
                Image(systemName: "clock.arrow.circlepath")
                Text(quota.countdownText)
                    .monospacedDigit()
                Spacer(minLength: 4)
                Text(presentation.isStale ? "数据稍旧" : presentation.updatedText)
                    .lineLimit(1)
            }
            .font(.system(size: 9, weight: .medium))
            .foregroundStyle(.secondary)
        }
    }
}

private struct MediumQuotaWidget: View {
    let presentation: WidgetQuotaPresentation

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            WidgetHeader(
                model: presentation.modelText,
                isStale: presentation.isStale
            )

            HStack(alignment: .top, spacing: 12) {
                ForEach(Array(presentation.quotas.prefix(2).enumerated()), id: \.element.id) {
                    index,
                    quota in
                    if index > 0 {
                        Divider()
                    }
                    MediumQuotaColumn(quota: quota)
                }
            }

            Spacer(minLength: 0)

            Text(presentation.isStale ? "数据稍旧 · 打开 CodexMeter 刷新" : presentation.updatedText)
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }
}

private struct MediumQuotaColumn: View {
    let quota: WidgetQuotaItemPresentation

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(quota.label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .lineLimit(1)

            Text(quota.percentageText)
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(quota.level.widgetColor)

            SegmentedQuotaBar(
                fillAmounts: quota.segmentFillAmounts,
                color: quota.level.widgetColor
            )

            Label(quota.countdownText, systemImage: "clock.arrow.circlepath")
                .font(.caption2.weight(.medium))
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct WidgetHeader: View {
    let model: String?
    let isStale: Bool

    var body: some View {
        HStack(spacing: 7) {
            Image(systemName: "gauge.medium")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.tint)

            VStack(alignment: .leading, spacing: 1) {
                Text("CodexMeter")
                    .font(.caption.weight(.semibold))
                if let model {
                    Text(model)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 4)

            Circle()
                .fill(isStale ? Color.orange : Color.green)
                .frame(width: 6, height: 6)
                .accessibilityLabel(isStale ? "数据稍旧" : "数据已更新")
        }
    }
}

private struct SegmentedQuotaBar: View {
    let fillAmounts: [Double]
    let color: Color

    var body: some View {
        HStack(spacing: 2) {
            ForEach(Array(fillAmounts.enumerated()), id: \.offset) { _, fill in
                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.primary.opacity(0.09))
                        Capsule()
                            .fill(color)
                            .frame(width: proxy.size.width * fill)
                    }
                }
            }
        }
        .frame(height: 5)
        .accessibilityHidden(true)
    }
}

private struct WidgetEmptyState: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            WidgetHeader(model: nil, isStale: true)
            Spacer(minLength: 0)
            Image(systemName: "gauge.with.dots.needle.0percent")
                .font(.system(size: 28, weight: .medium))
                .foregroundStyle(.secondary)
            Text("等待 Codex 数据")
                .font(.headline)
            Text("打开 CodexMeter 一次即可同步额度。")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
    }
}

private extension QuotaLevel {
    var widgetColor: Color {
        switch self {
        case .healthy:
            .green
        case .warning:
            .orange
        case .critical:
            .red
        }
    }
}

private extension View {
    @ViewBuilder
    func codexWidgetBackground() -> some View {
        if #available(macOS 14.0, *) {
            containerBackground(for: .widget) {
                Color(nsColor: .windowBackgroundColor)
            }
        } else {
            background(Color(nsColor: .windowBackgroundColor))
        }
    }
}
