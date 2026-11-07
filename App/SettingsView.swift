import SwiftUI

/// The content of the Settings window, opened with ⌘, from the app menu.
struct SettingsView: View {
  var body: some View {
    Color.clear
      .frame(width: 420, height: 240)
      .accessibilityElement(children: .contain)
      .accessibilityIdentifier("settings-window")
  }
}

#Preview {
  SettingsView()
}
