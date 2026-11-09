import SwiftUI

/// The two main actions under the History inspector's details, side by side at equal width: Open (prominent, only
/// while the file is at the entry's place) and Move Back to Inbox, or Put Back for a trashed entry.
struct HistoryEntryActions: View {
  let model: HistoryModel
  let entry: HistoryEntry

  var body: some View {
    HStack(spacing: 8) {
      if model.canOpen(entry) {
        Button("Open") { FileActions.open(entry.url) }
          .buttonStyle(.borderedProminent)
          .keyboardShortcut("o")
          .accessibilityIdentifier("history-open")
      }
      if let returnTitle = model.returnTitle(for: entry) {
        Button(returnTitle) {
          Task { await model.returnToInbox(entry) }
        }
        .keyboardShortcut("z", modifiers: [.option, .command])
        .disabled(!model.canReturnToInbox(entry))
        .accessibilityIdentifier("history-return")
      }
    }
    .buttonSizing(.flexible)
  }
}

/// The icon button that reveals the entry's file in Finder, or its folder when the file is no longer at the entry's
/// place; it sits at the end of the destination line in the History inspector.
struct HistoryRevealButton: View {
  let model: HistoryModel
  let entry: HistoryEntry

  var body: some View {
    let revealsFile = model.canOpen(entry)
    let title = revealsFile ? "Reveal in Finder" : "Reveal Folder in Finder"
    Button {
      FileActions.revealInFinder(revealsFile ? entry.url : entry.url.deletingLastPathComponent())
    } label: {
      Image(systemName: "folder")
    }
    .buttonStyle(.borderless)
    .keyboardShortcut("r", modifiers: [.option, .command])
    .help("\(title) (⌥⌘R)")
    .accessibilityLabel(title)
    .accessibilityIdentifier(revealsFile ? "history-reveal" : "history-reveal-folder")
  }
}

/// The context menu of a History row: Open, Reveal in Finder (or Reveal Folder in Finder), Move Back to Inbox or Put
/// Back, and Show in Main Window while the file is in this session's list.
struct HistoryEntryMenu: View {
  let model: HistoryModel
  let entry: HistoryEntry

  @Environment(\.openWindow) private var openWindow

  var body: some View {
    if model.canOpen(entry) {
      Button("Open") { FileActions.open(entry.url) }
      Button("Reveal in Finder") { FileActions.revealInFinder(entry.url) }
    } else {
      Button("Reveal Folder in Finder") {
        FileActions.revealInFinder(entry.url.deletingLastPathComponent())
      }
    }
    if let returnTitle = model.returnTitle(for: entry) {
      Button(returnTitle) {
        Task { await model.returnToInbox(entry) }
      }
      .disabled(!model.canReturnToInbox(entry))
    }
    if let rowID = model.inboxRowID(for: entry) {
      Divider()
      Button("Show in Main Window") {
        model.mainWindow.select(rowID)
        model.mainWindow.requestFocus(.sidebar)
        openWindow(id: SceneID.main)
      }
    }
  }
}

#if DEBUG
  #Preview("Actions") {
    let model = HistoryModel.preview(entries: HistorySampleEntries.entries)
    HistoryEntryActions(model: model, entry: HistorySampleEntries.entries[1])
      .padding()
      .frame(width: 300)
  }
#endif
