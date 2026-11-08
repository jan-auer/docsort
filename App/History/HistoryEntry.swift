import DocsortCore
import Foundation

/// What one History entry did to its file.
nonisolated enum HistoryEntryKind: Hashable, Sendable {
  /// Filed an inbox file into the archive.
  case filed
  /// Renamed a file in its folder.
  case renamed
  /// Moved a filed file on to another folder.
  case movedOn
  /// Moved a filed file back to its inbox.
  case movedBack
  /// Moved an inbox file to the Trash.
  case trashed
  /// Moved the item a Replace replaced to the Trash; it comes back only by undoing that move.
  case replaced
}

/// Whether an entry's file is still where the entry put it.
nonisolated enum HistoryEntryPlace: Hashable, Sendable {
  /// The file is still there.
  case current
  /// The entry was undone at this date, so the file is back where it was before.
  case undone(Date)
  /// The file is no longer there: moved on by a later entry, or moved or deleted outside docsort.
  case movedOrDeleted
}

/// One move or trash as the History window lists it.
nonisolated struct HistoryEntry: Identifiable, Hashable, Sendable {
  /// The filing event the entry shows.
  let id: FilingEvent.ID
  /// The filing history's document the entry moved or trashed: the file across its moves.
  let documentID: UUID
  /// When it happened.
  let date: Date
  /// What it did.
  let kind: HistoryEntryKind
  /// The file's name before the entry.
  let originalName: String
  /// The display name of the inbox the file came from; `nil` when it did not come from an inbox (an archive item a
  /// Replace sent to the Trash).
  let inboxName: String?
  /// The file's name after the entry; `nil` for a move to the Trash.
  let newName: String?
  /// Where the entry put the file, as the user reads it: an archive-relative folder path, the inbox, or "Trash".
  let destination: String
  /// Where the entry put the file.
  let url: URL
  /// Whether the file is still at `url`.
  let place: HistoryEntryPlace

  /// The file's name at `url`.
  var currentName: String {
    url.lastPathComponent
  }

  /// Whether the file is still where the entry put it.
  var isCurrent: Bool {
    place == .current
  }
}
