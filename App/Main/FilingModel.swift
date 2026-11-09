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
    do {
      let outcome = try await service.file(
        source, into: folder, archivePath: archivePath, named: name, resolution: resolution)
      apply(outcome.status)
      return outcome
    } catch {
      await refreshStatus()
      throw error
    }
  }

  /// Renames or moves on the filed document `documentID` at `source`; see `FilingService.refile`.
  func refile(
    document documentID: UUID, at source: URL, into folder: URL, archivePath: String,
    named name: String, resolution: ConflictResolution
  ) async throws(FilingError) -> MoveOutcome {
    do {
      let outcome = try await service.refile(
        document: documentID, at: source, into: folder, archivePath: archivePath, named: name,
        resolution: resolution)
      apply(outcome.status)
      return outcome
    } catch {
      await refreshStatus()
      throw error
    }
  }

  /// Renames the archive file at `url` to `name` in its folder; see `FilingService.rename`.
  func rename(_ url: URL, to name: String) async throws(FilingError) -> MoveOutcome {
    do {
      let outcome = try await service.rename(url, to: name)
      apply(outcome.status)
      return outcome
    } catch {
      await refreshStatus()
      throw error
    }
  }

  /// Moves `url` to the Trash; see `FilingService.trash`.
  func trash(_ url: URL) async throws(FilingError) -> TrashOutcome {
    do {
      let outcome = try await service.trash(url)
      apply(outcome.status)
      return outcome
    } catch {
      await refreshStatus()
      throw error
    }
  }

  /// Undoes the event `eventID`; see `FilingService.undo`.
  func undo(eventID: FilingEvent.ID) async throws(FilingError) -> UndoOutcome {
    do {
      let outcome = try await service.undo(eventID: eventID)
      apply(outcome.status)
      return outcome
    } catch {
      await refreshStatus()
      throw error
    }
  }

  /// Moves the filed document `documentID` at `currentURL` back to its inbox; see `FilingService.moveBack`.
  func moveBack(
    document documentID: UUID, at currentURL: URL, resolution: ConflictResolution
  ) async throws(FilingError) -> MoveOutcome {
    do {
      let outcome = try await service.moveBack(
        document: documentID, at: currentURL, resolution: resolution)
      apply(outcome.status)
      return outcome
    } catch {
      await refreshStatus()
      throw error
    }
  }

  /// Puts the file at `trashedURL` back from the Trash; see `FilingService.putBack`.
  func putBack(_ trashedURL: URL) async throws(FilingError) -> UndoOutcome {
    do {
      let outcome = try await service.putBack(trashedURL)
      apply(outcome.status)
      return outcome
    } catch {
      await refreshStatus()
      throw error
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

  private func refreshStatus() async {
    apply(await service.status())
  }

  private func apply(_ status: FilingStatus) {
    historyAvailability = status.historyAvailability
    pendingSaveError = status.pendingSaveError
    recents = status.recents
  }
}
