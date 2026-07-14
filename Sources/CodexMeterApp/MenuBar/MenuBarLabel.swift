import SwiftUI
import CodexMeterCore

struct MenuBarLabel: View {
    let presentation: MenuBarPresentation

    var body: some View {
        HStack(alignment: .center, spacing: 5) {
            Image(systemName: presentation.systemImageName)
                .symbolRenderingMode(.hierarchical)
                .frame(width: 14, height: 14, alignment: .center)

            Text(presentation.displayText)
                .fontWeight(.semibold)
                .monospacedDigit()
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(presentation.accessibilityLabel)
    }
}
