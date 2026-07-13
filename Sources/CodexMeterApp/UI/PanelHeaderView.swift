import CodexMeterCore
import SwiftUI

struct PanelHeaderView: View {
    let presentation: StatusPanelPresentation?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "bolt.circle.fill")
                    .font(.title2)
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.blue)

                Text("CodexMeter")
                    .font(.system(.title3, design: .rounded, weight: .semibold))

                Spacer()

                if let plan = presentation?.planText {
                    Text(plan)
                        .font(.caption2.weight(.semibold))
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(.blue.opacity(0.12), in: Capsule())
                        .foregroundStyle(.blue)
                }
            }

            HStack(spacing: 12) {
                Label(presentation?.accountText ?? "Codex 账号", systemImage: "person.crop.circle")
                Label(presentation?.modelText ?? "Codex", systemImage: "cpu")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(1)
        }
        .accessibilityElement(children: .combine)
    }
}
