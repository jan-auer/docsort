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
      inboxList
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
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
      Section("Eingangskorb") {
        Text("2026-03-02 Rechnung Beispiel GmbH.pdf")
        Text("2026-04-14 Notiz Musterfirma.txt")
      }
      Section("Scannerablage") {
        Text("Scan 0007.pdf")
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
