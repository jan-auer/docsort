import SwiftUI

/// The content of the main window.
struct MainWindowView: View {
  var body: some View {
    Color.clear
      .frame(minWidth: 480, minHeight: 320)
      .accessibilityElement(children: .contain)
      .accessibilityIdentifier("main-window")
  }
}

#Preview {
  MainWindowView()
}
