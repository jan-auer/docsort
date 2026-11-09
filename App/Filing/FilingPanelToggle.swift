import SwiftUI

/// The filing panel toggle, at the window's trailing edge as WWDC25 323 places its inspector toggle. SwiftUI has no
/// system toolbar toggle for an inspector, so it is the app's own button.
///
/// The filing panel declares it in its own toolbar, after the search field: an inspector's toolbar items get a
/// toolbar section of their own over the panel (SwiftUI adds a tracking separator at its edge), and the system keeps
/// them at the window's trailing edge while the panel is hidden. A flexible space before it keeps it trailing when the
/// search field isn't there. Its own piece, so the toolbar study can move it cheaply.
///
/// Accessibility: `toolbar-filing-panel`.
struct FilingPanelToggle: ToolbarContent {
  /// Whether the filing panel is shown.
  @Binding var isShown: Bool

  var body: some ToolbarContent {
    ToolbarSpacer(.flexible)
    ToolbarItem {
      Button {
        isShown.toggle()
      } label: {
        Label("Filing Panel", systemImage: "sidebar.trailing")
      }
      .help(
        "\(isShown ? "Hide" : "Show") Filing Panel (\(MenuCommand.toggleFilingPanel.keys.notation))"
      )
      .accessibilityIdentifier("toolbar-filing-panel")
    }
  }
}
