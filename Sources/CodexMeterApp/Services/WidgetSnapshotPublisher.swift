import Foundation
import WidgetKit
import CodexMeterCore

struct AppWidgetSnapshotPublisher: WidgetSnapshotPublishing {
    func publish(_ snapshot: ProviderSnapshot) async {
        guard let store = WidgetSnapshotStore.sharedApplicationSupport() else {
            return
        }

        do {
            try store.write(WidgetQuotaSnapshot(snapshot: snapshot))
        } catch {
            return
        }

        WidgetCenter.shared.reloadTimelines(ofKind: WidgetConfiguration.widgetKind)
    }
}
