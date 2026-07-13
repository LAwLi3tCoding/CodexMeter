import SwiftUI
import WidgetKit
import CodexMeterCore

struct CodexMeterQuotaWidget: Widget {
    var body: some SwiftUI.WidgetConfiguration {
        StaticConfiguration(
            kind: CodexMeterCore.WidgetConfiguration.widgetKind,
            provider: QuotaTimelineProvider()
        ) { entry in
            QuotaWidgetView(entry: entry)
        }
        .configurationDisplayName("Codex 额度")
        .description("在桌面和通知中心查看 Codex 剩余额度与重置时间。")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
