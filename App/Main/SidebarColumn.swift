import SwiftUI

/// The main window's sidebar column: the inbox list on top and, below a hairline at the very bottom, the fixed
/// History row that opens the History window.
///
/// The inbox list is the `inboxList` view builder: the sidebar step passes its list of inbox sections there. The
/// column gives it all the height above the History row, aligned to the top, and adds nothing else around it.
struct SidebarColumn<InboxList: View>: View {
  /// The inbox sections, filled in by the sidebar step.
  @ViewBuilder let inboxList: InboxList

  @Environment(\.openWindow) private var openWindow

  var body: some View {
    VStack(spacing: 0) {
      // The clear background takes the height even when the list is empty (first launch), so the History row
      // stays at the bottom; a frame on an empty view builder would take no space.
      ZStack(alignment: .top) {
        Color.clear
        inboxList
      }
      Divider()
      historyRow
    }
    .accessibilityElement(children: .contain)
    .accessibilityIdentifier("sidebar")
  }

  private var historyRow: some View {
    Button {
      openWindow(id: SceneID.history)
    } label: {
      HStack(spacing: 6) {
        Label("History", systemImage: "clock")
        Spacer(minLength: 8)
        Text("⌘Y")
          .foregroundStyle(.secondary)
          .accessibilityHidden(true)
      }
      .padding(.horizontal, 12)
      .padding(.vertical, 8)
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .help("Show History (⌘Y)")
    .accessibilityIdentifier("sidebar-history")
  }
}

#Preview("Sidebar with invented inboxes") {
  SidebarColumn {
    List {
      Section("Web-Downloads") {
        Text("Rechnung_NA-33-08812.pdf")
        Text("2033-10-20 Verlängerung Jahreskarte Konrad.pdf")
      }
      Section("Scanner") {
        Text("2033-10-11_Optik Klarblick.pdf")
      }
    }
    .listStyle(.sidebar)
  }
  .frame(width: 260, height: 480)
}

#Preview("Empty sidebar") {
  SidebarColumn {}
    .frame(width: 260, height: 480)
}
