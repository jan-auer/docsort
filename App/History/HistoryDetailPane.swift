import SwiftUI

/// The History window's right pane: the selected entry's file at its current place, what the entry did, and the
/// actions on it: Open, Reveal in Finder, Move Back to Inbox or Put Back, and Show in Main Window. An entry whose file
/// is no longer where the entry put it offers only Reveal Folder in Finder.
struct HistoryDetailPane: View {
  let model: HistoryModel

  @State private var previewController = PreviewController()
  @Environment(\.openWindow) private var openWindow

  var body: some View {
    if let entry = model.selectedEntry {
      VStack(alignment: .leading, spacing: 10) {
        filePreview(of: entry)
          .frame(height: 240)
          .clipShape(RoundedRectangle(cornerRadius: 6))
        facts(of: entry)
        actions(for: entry)
        Spacer(minLength: 0)
      }
      .padding(12)
      .accessibilityElement(children: .contain)
      .accessibilityIdentifier("history-detail")
    } else {
      ContentUnavailableView("No entry selected", systemImage: "clock")
    }
  }

  @ViewBuilder private func filePreview(of entry: HistoryEntry) -> some View {
    if entry.isCurrent {
      PreviewView(
        document: PreviewDocument(url: entry.url, completeness: .complete),
        controller: previewController)
    } else {
      ContentUnavailableView(
        "Not at this place", systemImage: "doc.questionmark",
        description: Text(entry.currentName)
      )
      .background(.quaternary)
    }
  }

  private func facts(of entry: HistoryEntry) -> some View {
    VStack(alignment: .leading, spacing: 3) {
      Text(entry.newName ?? entry.originalName)
        .font(.headline)
        .accessibilityIdentifier("history-detail-name")
      Text(entry.destination)
      Text(subtitle(of: entry))
        .font(.caption)
        .foregroundStyle(.secondary)
      if let notice = notice(for: entry) {
        Label(notice, systemImage: "exclamationmark.triangle.fill")
          .font(.caption)
          .foregroundStyle(.orange)
          .padding(.top, 4)
          .accessibilityIdentifier("history-detail-notice")
      }
    }
    .textSelection(.enabled)
    .fixedSize(horizontal: false, vertical: true)
  }

  private func actions(for entry: HistoryEntry) -> some View {
    VStack(alignment: .leading, spacing: 6) {
      if model.canOpen(entry) {
        HStack(spacing: 6) {
          Button("Open") { FileActions.open(entry.url) }
            .keyboardShortcut("o")
            .accessibilityIdentifier("history-open")
          Button("Reveal in Finder") { FileActions.revealInFinder(entry.url) }
            .keyboardShortcut("r", modifiers: [.option, .command])
            .accessibilityIdentifier("history-reveal")
        }
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
    .controlSize(.small)
  }

  /// When the entry happened, the inbox the file came from, and its earlier name when the entry renamed it.
  private func subtitle(of entry: HistoryEntry) -> String {
    var parts = [entry.date.formatted(date: .abbreviated, time: .shortened)]
    if let inboxName = entry.inboxName { parts.append("from \(inboxName)") }
    if let newName = entry.newName, newName != entry.originalName {
      parts.append("was “\(entry.originalName)”")
    }
    return parts.joined(separator: " · ")
  }

  /// Why the file is no longer where the entry put it; `nil` while it is.
  private func notice(for entry: HistoryEntry) -> String? {
    switch entry.place {
    case .current:
      nil
    case .undone(let date):
      "Undone \(date.formatted(date: .abbreviated, time: .shortened)). The file is no longer at this place."
    case .movedOrDeleted:
      "Moved or deleted since. The file is no longer at this place."
    }
  }
}
