import SwiftUI
import CodexMeterCore

struct MenuBarLabel: View {
    let presentation: MenuBarPresentation

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: presentation.systemImageName)
            Text(presentation.labelText)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(presentation.accessibilityLabel)
    }
}
