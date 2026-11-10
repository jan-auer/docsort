import DocsortCore
import Foundation

/// Whether the filing history could be loaded, which decides whether files can be moved and trashed.
nonisolated enum FilingHistoryAvailability: Equatable, Sendable {
  /// The history has not been loaded yet.
  case loading
  /// The history is loaded (or there was none yet); filing works.
  case available
  /// The history file exists but cannot be read. It is never saved over; moving and trashing are refused until the
  /// user starts a new history.
  case unreadable(FilingHistoryStoreError)
}

/// The filing service's state, as the window shows it.
nonisolated struct FilingStatus: Equatable, Sendable {
  /// Whether the history could be loaded.
  let historyAvailability: FilingHistoryAvailability
  /// Why the last save of the history failed; `nil` once a save succeeded. The changes are kept in memory and the
  /// save is retried before every later operation.
  let pendingSaveError: FilingHistoryStoreError?
  /// The recent destinations, most recent first.
  let recents: RecentDestinations
}

/// What a completed filing operation returns: at least the service's state after it.
nonisolated protocol FilingOutcome: Sendable {
  /// The service's state after the operation.
  var status: FilingStatus { get }
}

/// A completed move.
nonisolated struct MoveOutcome: FilingOutcome {
  /// The history event recording the move.
  let event: FilingEvent
  /// What the move did, including where the file is now.
  let record: MoveRecord
  /// The history event recording the trip to the Trash of the item a Replace took the place of; `nil` when the move
  /// replaced nothing. Its document is the replaced file's, so whatever showed that file can show it as trashed.
  let replacedEvent: FilingEvent?
  /// The service's state after the move.
  let status: FilingStatus

  /// Where the file is now.
  var movedURL: URL { record.destinationURL }
}

/// A completed move to the Trash.
nonisolated struct TrashOutcome: FilingOutcome {
  /// The history event recording the trash.
  let event: FilingEvent
  /// What the trash did.
  let record: TrashRecord
  /// The service's state after the trash.
  let status: FilingStatus
}

/// A completed undo.
nonisolated struct UndoOutcome: FilingOutcome {
  /// The event that was undone.
  let eventID: FilingEvent.ID
  /// The filing history's document the event moved or trashed.
  let documentID: UUID
  /// Where the file is back now.
  let restored: RestoredItem
  /// The service's state after the undo.
  let status: FilingStatus
}

/// Why a filing operation did not happen.
nonisolated enum FilingError: Error, Equatable, Sendable {
  /// The filing history cannot be read, so nothing is moved or trashed until a new history is started.
  case historyUnreadable(FilingHistoryStoreError)
  /// The file operation failed; the core's error says why. A name conflict is
  /// `.fileOperation(.nameConflict(existing:))`, which the caller can retry with another resolution.
  case fileOperation(FileOperationError)
  /// The history refuses the undo, for example because a later event of the same file must be undone first.
  case undoRefused(FilingHistoryError)
  /// The unreadable history file could not be set aside to start a new one.
  case setAsideFailed(url: URL, reason: String)
  /// The history has no record of how the file at this URL got there: for Move Back, no move of it into the archive
  /// (its latest active event); for Put Back, no move of it to the Trash.
  case noHistoryRecord(URL)
  /// The history says another document is at this URL now than the filed one asked for (a Replace or a later filing
  /// took its place), so nothing is moved.
  case fileChangedSinceFiling(URL)
}
