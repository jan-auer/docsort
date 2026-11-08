import SwiftUI

/// The actions on the History window's selected entry, stacked at equal width under its details: Open and Reveal in
/// Finder while the file is at the entry's place (otherwise Reveal Folder in Finder), Move Back to Inbox or Put Back,
/// and Show in Main Window while the file is in this session's list.
struct HistoryEntryActions: View {
  let model: HistoryModel
  let entry: HistoryEntry

  @Environment(\.openWindow) private var openWindow

  var body: some View {
    VStack(spacing: 6) {
      if model.canOpen(entry) {
        Button("Open") { FileActions.open(entry.url) }
          .keyboardShortcut("o")
          .accessibilityIdentifier("history-open")
        Button("Reveal in Finder") { FileActions.revealInFinder(entry.url) }
          .keyboardShortcut("r", modifiers: [.option, .command])
          .accessibilityIdentifier("history-reveal")
      } else {
        Button("Reveal Folder in Finder") {
          FileActions.revealInFinder(entry.url.deletingLastPathComponent())
        }
        .accessibilityIdentifier("history-reveal-folder")
      }
      if let returnAction = model.returnAction(for: entry) {
        Button(returnAction == .putBack ? "Put Back" : "Move Back to Inbox") {
          Task { await model.returnToInbox(entry) }
        }
        .keyboardShortcut("z", modifiers: [.option, .command])
        .disabled(!model.canReturnToInbox(entry))
        .accessibilityIdentifier("history-return")
      }
      if let rowID = model.inboxRowID(for: entry) {
        Button("Show in Main Window") {
          model.mainWindow.select(rowID)
          model.mainWindow.requestFocus(.sidebar)
          openWindow(id: SceneID.main)
        }
        .accessibilityIdentifier("history-show-in-main-window")
      }
    }
    .buttonSizing(.flexible)
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
