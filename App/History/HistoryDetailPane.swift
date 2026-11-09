import SwiftUI

/// The History window's inspector: the selected entry's file at its current place, taking the height that its details
/// and actions below leave; what the entry did, with Reveal in Finder at the end of the destination line; and Open and
/// the return action, Move Back to Inbox, Revert Name or Put Back (`HistoryEntryActions`). Show in Main Window is in
/// the row's context menu.
struct HistoryDetailPane: View {
  let model: HistoryModel

  @State private var previewController = PreviewController()

  var body: some View {
    if let entry = model.selectedEntry {
      VStack(alignment: .leading, spacing: 12) {
        filePreview(of: entry)
          .frame(maxWidth: .infinity, minHeight: 160, idealHeight: 240, maxHeight: .infinity)
          .clipShape(RoundedRectangle(cornerRadius: 6))
        facts(of: entry)
        HistoryEntryActions(model: model, entry: entry)
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
      HStack(alignment: .firstTextBaseline, spacing: 6) {
        Text(entry.destination)
          .frame(maxWidth: .infinity, alignment: .leading)
        HistoryRevealButton(model: model, entry: entry)
      }
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
    .frame(maxWidth: .infinity, alignment: .leading)
    .textSelection(.enabled)
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
