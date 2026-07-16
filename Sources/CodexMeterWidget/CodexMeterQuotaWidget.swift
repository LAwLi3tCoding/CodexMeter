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
        .configurationDisplayName("Codex Quota")
        .description("View remaining Codex quota and reset times on the desktop and in Notification Center.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
