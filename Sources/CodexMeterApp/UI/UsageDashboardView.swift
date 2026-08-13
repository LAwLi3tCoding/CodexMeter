import AppKit
import Charts
import CodexMeterCore
import SwiftUI

struct UsageDashboardView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var hoveredDayID: String?

    let presentation: UsageDashboardPresentation
    var isStale = false

    private let accent = Color(nsColor: .systemBlue)
    private let streakAccent = Color(red: 0.96, green: 0.29, blue: 0.10)

    private var hoveredDay: DailyUsagePresentation? {
        presentation.days.first { $0.id == hoveredDayID }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("30-DAY TOKEN SKYLINE")
                        .font(.caption2.weight(.bold))
                        .tracking(0.8)
                        .foregroundStyle(.secondary)
                    Text("Local Codex usage")
                        .font(.caption.weight(.semibold))
                }

                Spacer()

                if let streak = presentation.streakText {
                    Label(streak, systemImage: "flame.fill")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(streakAccent)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 4)
                        .background {
                            Capsule()
                                .fill(streakAccent.opacity(0.24))
                        }
                        .overlay {
                            Capsule()
                                .strokeBorder(streakAccent.opacity(0.46), lineWidth: 1)
                        }
                }
            }

            if isStale {
                Label("Showing the last usage update · refresh failed", systemImage: "exclamationmark.arrow.trianglehead.2.clockwise.rotate.90")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(spacing: 0) {
                ForEach(Array(presentation.metrics.enumerated()), id: \.offset) { index, metric in
                    UsageMetricTile(metric: metric)
                    if index < presentation.metrics.count - 1 {
                        Divider()
                            .frame(height: 30)
                    }
                }
            }
            .padding(.vertical, 3)
            .background(Color.primary.opacity(0.03), in: RoundedRectangle(cornerRadius: 9, style: .continuous))

            ZStack(alignment: .topLeading) {
                Chart {
                    ForEach(presentation.days) { day in
                        BarMark(
                            x: .value("Day", day.date, unit: .day),
                            y: .value("Tokens", day.tokens)
                        )
                        .foregroundStyle(
                            accent.opacity(day.id == hoveredDayID ? 1 : (day.isToday ? 0.85 : 0.55))
                        )
                        .cornerRadius(2)
                        .accessibilityLabel(day.accessibilityLabel)
                    }

                    if let hoveredDay {
                        RuleMark(x: .value("Selected day", hoveredDay.date, unit: .day))
                            .foregroundStyle(accent.opacity(0.45))
                            .lineStyle(StrokeStyle(lineWidth: 1, dash: [2, 2]))
                            .accessibilityHidden(true)
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day, count: 7)) { value in
                        AxisGridLine()
                            .foregroundStyle(Color.primary.opacity(0.04))
                        AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .chartYAxis(.hidden)
                .chartPlotStyle { plot in
                    plot
                        .background(accent.opacity(0.035))
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .chartOverlay { proxy in
                    GeometryReader { geometry in
                        Rectangle()
                            // A tiny non-zero alpha keeps hover hit testing reliable
                            // inside a transient MenuBarExtra panel.
                            .fill(Color.primary.opacity(0.001))
                            .contentShape(Rectangle())
                            .onContinuousHover(coordinateSpace: .local) { phase in
                                updateHover(
                                    phase,
                                    proxy: proxy,
                                    geometry: geometry
                                )
                            }
                    }
                }

                if let hoveredDay {
                    UsageHoverCard(day: hoveredDay)
                        .padding(5)
                        .allowsHitTesting(false)
                        .zIndex(2)
                } else {
                    Text("Hover a bar for exact tokens")
                        .font(.system(size: 8, weight: .medium))
                        .foregroundStyle(accent.opacity(0.9))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 3)
                        .background(.regularMaterial, in: Capsule())
                        .padding(5)
                        .frame(maxWidth: .infinity, alignment: .topTrailing)
                        .allowsHitTesting(false)
                }
            }
            .frame(height: 82)
            .animation(
                reduceMotion ? nil : .easeOut(duration: 0.22),
                value: presentation.days.map(\.tokens)
            )
            .accessibilityLabel("Thirty-day daily token usage chart")

            HStack {
                Text(presentation.chartCaption)
                Spacer()
                Text(presentation.updatedText)
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
            .monospacedDigit()

            HStack(spacing: 6) {
                ModelUsageCell(
                    label: "CURRENT CONFIG",
                    value: presentation.currentModelText,
                    symbol: "slider.horizontal.3"
                )
                ModelUsageCell(
                    label: "TOP · 7D THREADS",
                    value: presentation.topModelText,
                    symbol: "crown.fill",
                    helpText: presentation.modelAttributionNote
                )
            }

            HStack(spacing: 6) {
                Image(systemName: presentation.paceSymbol)
                    .foregroundStyle(accent)
                Text("7-day pace")
                    .fontWeight(.semibold)
                Text(presentation.paceText)
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .font(.caption2)

            Label("USD estimate · observed-model basis", systemImage: "exclamationmark.circle")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .help(presentation.estimationNote)
        }
        .padding(10)
        .background {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
                .overlay {
                    LinearGradient(
                        colors: [accent.opacity(0.035), .clear],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
        }
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
        }
    }

    private func updateHover(
        _ phase: HoverPhase,
        proxy: ChartProxy,
        geometry: GeometryProxy
    ) {
        switch phase {
        case let .active(location):
            let plotFrame = geometry[proxy.plotAreaFrame]
            guard plotFrame.contains(location),
                  let date: Date = proxy.value(
                    atX: location.x - plotFrame.minX,
                    as: Date.self
                  ) else {
                hoveredDayID = nil
                return
            }
            hoveredDayID = presentation.days.min { lhs, rhs in
                abs(lhs.date.timeIntervalSince(date)) < abs(rhs.date.timeIntervalSince(date))
            }?.id
        case .ended:
            hoveredDayID = nil
        }
    }
}

private struct UsageMetricTile: View {
    let metric: UsageMetricPresentation

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(metric.label)
                .font(.system(size: 9, weight: .semibold))
                .tracking(0.35)
                .foregroundStyle(.secondary)
            Text(metric.tokenText)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(metric.costText)
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 5)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(metric.accessibilityLabel)
        .help("\(metric.exactTokenText) tokens")
    }
}

private struct UsageHoverCard: View {
    let day: DailyUsagePresentation

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(day.dateText)
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(.secondary)
            Text("\(day.tokenText) tokens")
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .monospacedDigit()
            Text(day.costText)
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 5)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.1), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.12), radius: 5, y: 2)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(day.accessibilityLabel)
    }
}

private struct ModelUsageCell: View {
    let label: String
    let value: String
    let symbol: String
    var helpText: String?

    var body: some View {
        HStack(spacing: 7) {
            Image(systemName: symbol)
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.secondary)
                .frame(width: 16)

            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.caption2.weight(.bold))
                    .tracking(0.5)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                    .help(helpText ?? value)
            }
            Spacer(minLength: 0)
        }
        .padding(7)
        .frame(maxWidth: .infinity)
        .background(Color.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(label), \(value). \(helpText ?? "")")
    }
}
