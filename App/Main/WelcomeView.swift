import SwiftUI

/// Shown in place of the preview until an archive folder and inbox folders are configured.
struct WelcomeView: View {
  @Environment(\.openSettings) private var openSettings

  var body: some View {
    ContentUnavailableView {
      Label("Welcome to docsort", systemImage: "tray.and.arrow.down")
    } description: {
      Text("Choose your archive folder and inbox folders to start.")
    } actions: {
      Button("Open Settings…") {
        openSettings()
      }
      .help("Open Settings (⌘,)")
      .accessibilityIdentifier("welcome-open-settings")
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .accessibilityElement(children: .contain)
    .accessibilityIdentifier("welcome")
  }
}

#Preview {
  WelcomeView()
    .frame(width: 620, height: 520)
}
