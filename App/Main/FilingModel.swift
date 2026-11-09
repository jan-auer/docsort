import DocsortCore
import Foundation
import Observation

/// The main actor's view of the `FilingService`: forwards the window's filing requests to it and mirrors its state
/// (history availability, pending save error, recents) after every call, so views can show it.
///
/// One per app. It decides nothing itself; the window model words messages and applies outcomes.
@Observable
final class FilingModel {
  /// Whether the filing history could be loaded.
  private(set) var historyAvailability: FilingHistoryAvailability = .loading
  /// Why the last history save failed, while a save is pending.
  private(set) var pendingSaveError: FilingHistoryStoreError?
  /// The recent destinations, most recent first.
  private(set) var recents = RecentDestinations()
  /// The history file, for Show in Finder.
  let historyFileURL: URL

  @ObservationIgnored private let service: FilingService

  /// A model forwarding to `service`, whose history lives at `historyFileURL`. Loads the service's state at once.
  init(service: FilingService, historyFileURL: URL) {
    self.service = service
    self.historyFileURL = historyFileURL
    Task { [weak self] in
      let status = await service.status()
      self?.apply(status)
    }
  }

  /// Whether files can be moved and trashed: the history is loaded and readable.
  var isHistoryWritable: Bool {
    historyAvailability == .available
  }

  /// Moves `source` into `folder` (archive-relative `archivePath`) as `name`; see `FilingService.file`.
  func file(
    _ source: URL, into folder: URL, archivePath: String, named name: String,
    resolution: ConflictResolution
  ) async throws(FilingError) -> MoveOutcome {
    try await mirroringStatus { service throws(FilingError) in
      try await service.file(
        source, into: folder, archivePath: archivePath, named: name, resolution: resolution)
    }
  }

  /// Renames or moves on the filed document `documentID` at `source`; see `FilingService.refile`.
  func refile(
    document documentID: UUID, at source: URL, into folder: URL, archivePath: String,
    named name: String, resolution: ConflictResolution
  ) async throws(FilingError) -> MoveOutcome {
    try await mirroringStatus { service throws(FilingError) in
      try await service.refile(
        document: documentID, at: source, into: folder, archivePath: archivePath, named: name,
        resolution: resolution)
    }
  }

  /// Renames the archive file at `url` to `name` in its folder; see `FilingService.rename`.
  func rename(_ url: URL, to name: String) async throws(FilingError) -> MoveOutcome {
    try await mirroringStatus { service throws(FilingError) in
      try await service.rename(url, to: name)
    }
  }

  /// Moves `url` to the Trash; see `FilingService.trash`.
  func trash(_ url: URL) async throws(FilingError) -> TrashOutcome {
    try await mirroringStatus { service throws(FilingError) in try await service.trash(url) }
  }

  /// Undoes the event `eventID`; see `FilingService.undo`.
  func undo(eventID: FilingEvent.ID) async throws(FilingError) -> UndoOutcome {
    try await mirroringStatus { service throws(FilingError) in
      try await service.undo(eventID: eventID)
    }
  }

  /// Moves the filed document `documentID` at `currentURL` back to its inbox; see `FilingService.moveBack`.
  func moveBack(
    document documentID: UUID, at currentURL: URL, resolution: ConflictResolution
  ) async throws(FilingError) -> MoveOutcome {
    try await mirroringStatus { service throws(FilingError) in
      try await service.moveBack(document: documentID, at: currentURL, resolution: resolution)
    }
  }

  /// Puts the file at `trashedURL` back from the Trash; see `FilingService.putBack`.
  func putBack(_ trashedURL: URL) async throws(FilingError) -> UndoOutcome {
    try await mirroringStatus { service throws(FilingError) in try await service.putBack(trashedURL)
    }
  }

  /// Every event of the filing history, oldest first; see `FilingService.events`.
  func events() async -> [FilingEvent] {
    await service.events()
  }

  /// Tries the pending history save again.
  func retrySave() async {
    apply(await service.retrySave())
  }

  /// Sets the unreadable history aside and starts a new one.
  func startNewHistory() async throws(FilingError) {
    apply(try await service.startNewHistory())
  }

  /// Saves a pending change before quitting; `false` when it still fails.
  func saveBeforeQuit() async -> Bool {
    let isSaved = await service.saveBeforeQuit()
    await refreshStatus()
    return isSaved
  }

  /// Runs `operation` on the service and mirrors the state it leaves: the outcome's on success, a fresh one when it
  /// throws (a failed operation may still have loaded the history or retried a save).
  private func mirroringStatus<Outcome: FilingOutcome>(
    _ operation: (FilingService) async throws(FilingError) -> Outcome
  ) async throws(FilingError) -> Outcome {
    do {
      let outcome = try await operation(service)
      apply(outcome.status)
      return outcome
    } catch {
      await refreshStatus()
      throw error
    }
  }

  private func refreshStatus() async {
    apply(await service.status())
  }

  private func apply(_ status: FilingStatus) {
    historyAvailability = status.historyAvailability
    pendingSaveError = status.pendingSaveError
    recents = status.recents
  }
}
