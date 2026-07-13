import Foundation
import WidgetKit
import CodexMeterCore

struct AppWidgetSnapshotPublisher: WidgetSnapshotPublishing {
    func publish(_ snapshot: ProviderSnapshot) async {
        guard let defaults = UserDefaults(suiteName: WidgetConfiguration.appGroupID) else {
            return
        }

        do {
            try WidgetSnapshotStore(defaults: defaults).write(
                WidgetQuotaSnapshot(snapshot: snapshot)
            )
        } catch {
            return
        }

        WidgetCenter.shared.reloadTimelines(ofKind: WidgetConfiguration.widgetKind)
    }
}
