import DocsortCore
import Foundation
import OSLog

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

/// A completed move.
nonisolated struct MoveOutcome: Sendable {
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
nonisolated struct TrashOutcome: Sendable {
  /// The history event recording the trash.
  let event: FilingEvent
  /// What the trash did.
  let record: TrashRecord
  /// The service's state after the trash.
  let status: FilingStatus
}

/// A completed undo.
nonisolated struct UndoOutcome: Sendable {
  /// The event that was undone.
  let eventID: FilingEvent.ID
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

/// Moves, trashes and undoes inbox files, keeping the filing history and the recent destinations in step.
///
/// The only owner of `FileOperations`, `FilingHistory`, `FilingHistoryStore` and `RecentDestinations` in the app.
/// Every operation is perform → record → save inside one actor call, so the history never falls behind the disk, and
/// returns an outcome value the main-actor models apply. It holds no UI strings.
///
/// The history and recents are loaded on first use. Failure policy (approved): a history that cannot be read is
/// never saved over, and moving and trashing throw `historyUnreadable` until `startNewHistory()` sets the file aside.
/// A save that fails keeps the change and the in-memory history and is exposed as `pendingSaveError`; it is retried
/// before every later operation, by `retrySave()`, and by `saveBeforeQuit()`.
///
/// Uses only Foundation, DocsortCore and OSLog, so it can move into the core later.
actor FilingService {
  private let store: FilingHistoryStore
  private let recentsPreference: StoredPreference<RecentDestinations>
  private let fileOperations: FileOperations
  /// Every file operation runs through it, so the inbox watcher leaves the operation's own changes out.
  private let expectedChanges: ExpectedChanges

  /// Whether `history`, `unreadableError` and `recents` have been loaded.
  private var isLoaded = false
  /// The history; `nil` while it is not loaded or cannot be read.
  private var history: FilingHistory?
  /// Why the history file cannot be read, while it cannot.
  private var unreadableError: FilingHistoryStoreError?
  private var recents = RecentDestinations()
  private var pendingSaveError: FilingHistoryStoreError?

  /// A service keeping its history at `historyURL` and its recents in `recentsPreference`, moving files with
  /// `fileOperations` and registering each operation's changes with `expectedChanges`, which must be the instance the
  /// app's `InboxWatcher` uses.
  init(
    historyURL: URL, recentsPreference: StoredPreference<RecentDestinations>,
    fileOperations: FileOperations, expectedChanges: ExpectedChanges
  ) {
    store = FilingHistoryStore(fileURL: historyURL)
    self.recentsPreference = recentsPreference
    self.fileOperations = fileOperations
    self.expectedChanges = expectedChanges
  }

  #if DEBUG
    /// A service with a registry of its own, for previews and tests that watch no inbox.
    init(
      historyURL: URL, recentsPreference: StoredPreference<RecentDestinations>,
      fileOperations: FileOperations
    ) {
      self.init(
        historyURL: historyURL, recentsPreference: recentsPreference,
        fileOperations: fileOperations, expectedChanges: ExpectedChanges())
    }
  #endif

  /// The service for `environment`: its history file and defaults, and its Trash, registering its changes with
  /// `expectedChanges`.
  @MainActor static func make(
    environment: AppEnvironment, expectedChanges: ExpectedChanges
  ) -> FilingService {
    FilingService(
      historyURL: environment.filingHistoryURL,
      recentsPreference: RecentDestinations.preference(in: environment.defaults),
      fileOperations: FileOperations(trash: environment.fileTrash),
      expectedChanges: expectedChanges)
  }

  /// The current state, loading the history and recents first if needed.
  func status() -> FilingStatus {
    loadIfNeeded()
    return currentStatus
  }

  private var currentStatus: FilingStatus {
    let availability: FilingHistoryAvailability =
      if !isLoaded {
        .loading
      } else if let unreadableError {
        .unreadable(unreadableError)
      } else {
        .available
      }
    return FilingStatus(
      historyAvailability: availability, pendingSaveError: pendingSaveError, recents: recents)
  }

  // MARK: Operations

  /// Moves the inbox file `source` into `folder` (the archive folder at archive-relative `archivePath`) under `name`,
  /// records the move and the destination, and saves both.
  ///
  /// A taken name throws `.fileOperation(.nameConflict(existing:))` with `.refuse`; retry with `.keepBoth` or
  /// `.replace`.
  func file(
    _ source: URL, into folder: URL, archivePath: String, named name: String,
    resolution: ConflictResolution
  ) throws(FilingError) -> MoveOutcome {
    let history = try writableHistory()
    return try move(
      source, into: folder, archivePath: archivePath, named: name, resolution: resolution,
      in: history)
  }

  /// Renames or moves on the filed document `documentID`, which lies at `source`, into `folder` (archive-relative
  /// `archivePath`) under `name`, records the move and the destination, and saves both.
  ///
  /// Refuses, changing nothing, unless `documentID` is still the file at `source` (see `verifyFiledPlacement`):
  /// `.fileChangedSinceFiling` when the history has another document there, `.fileOperation(.sourceMissing)` or
  /// `.fileOperation(.differentItem)` when the item on disk is gone or not the one filed. Conflicts as in `file`.
  func refile(
    document documentID: UUID, at source: URL, into folder: URL, archivePath: String,
    named name: String, resolution: ConflictResolution
  ) throws(FilingError) -> MoveOutcome {
    let history = try writableHistory()
    try verifyFiledPlacement(of: documentID, at: source, in: history)
    return try move(
      source, into: folder, archivePath: archivePath, named: name, resolution: resolution,
      in: history)
  }

  /// Moves `source` into `folder` under `name`, records the move into `history` and the destination, and saves both.
  private func move(
    _ source: URL, into folder: URL, archivePath: String, named name: String,
    resolution: ConflictResolution, in history: FilingHistory
  ) throws(FilingError) -> MoveOutcome {
    var history = history
    let record: MoveRecord
    do {
      record = try expectedChanges.perform(
        { () throws(FileOperationError) in
          try fileOperations.move(source, into: folder, named: name, resolution: resolution)
        }, expecting: Self.changes(madeBy:))
    } catch {
      throw .fileOperation(error)
    }
    let event = history.recordMove(record, at: Date())
    let replacedEvent =
      record.replaced == nil ? nil : history.events.last { $0.causedBy == event.id }
    self.history = history
    recents.record(archivePath)
    save()
    Logger.filing.notice(
      "Filed \(source.lastPathComponent, privacy: .private) to \(archivePath, privacy: .private)")
    return MoveOutcome(
      event: event, record: record, replacedEvent: replacedEvent, status: currentStatus)
  }

  /// Moves `url` to the Trash, records it and saves the history.
  func trash(_ url: URL) throws(FilingError) -> TrashOutcome {
    var history = try writableHistory()
    let record: TrashRecord
    do {
      record = try expectedChanges.perform(
        { () throws(FileOperationError) in try fileOperations.moveToTrash(url) },
        expecting: { record in [.removal(of: record.originalURL)] })
    } catch {
      throw .fileOperation(error)
    }
    let event = history.recordTrash(record, at: Date())
    self.history = history
    save()
    Logger.filing.notice("Moved \(url.lastPathComponent, privacy: .private) to the Trash")
    return TrashOutcome(event: event, record: record, status: currentStatus)
  }

  /// Undoes the event `eventID` (a move or a trash), records the undo and saves the history.
  ///
  /// Refuses, changing nothing, when the history or the disk says it cannot be undone. Never replaces anything: a
  /// taken original location throws `.fileOperation(.originalLocationTaken)`.
  func undo(eventID: FilingEvent.ID) throws(FilingError) -> UndoOutcome {
    var history = try writableHistory()
    if let blocker = history.undoBlocker(for: eventID) { throw .undoRefused(blocker) }
    guard let event = history.events.first(where: { $0.id == eventID }) else {
      throw .undoRefused(.unknownEvent(eventID))
    }
    let restored: RestoredItem
    do throws(FileOperationError) {
      restored = try expectedChanges.perform(
        { () throws(FileOperationError) in
          switch event.action {
          case .moved(let record):
            if let blocker = fileOperations.undoBlocker(for: record) { throw blocker }
            return try fileOperations.undo(record, resolution: .refuse)
          case .trashed(let record):
            if let blocker = fileOperations.undoBlocker(for: record) { throw blocker }
            return try fileOperations.undo(record)
          }
        }, expecting: { restored in Self.changes(undoing: event.action, restoredTo: restored) })
    } catch {
      throw .fileOperation(error)
    }
    do {
      try history.recordUndo(of: eventID, restoredTo: restored, at: Date())
    } catch {
      // The file is back; the history checked above that it may be undone, so this means the history changed in
      // between, which the actor rules out. Report it rather than hide it.
      Logger.filing.fault(
        "The undo of \(eventID, privacy: .public) succeeded on disk but the history refused it: \(error.description, privacy: .public)"
      )
      throw .undoRefused(error)
    }
    self.history = history
    save()
    Logger.filing.notice("Undid filing event \(eventID, privacy: .public)")
    return UndoOutcome(eventID: eventID, restored: restored, status: currentStatus)
  }

  /// Moves the filed document `documentID`, which lies at `currentURL`, back to where it came from: the folder and
  /// name it had before its first recorded move (`FilingHistory.origin(ofDocument:)`), also after a restart. Records
  /// the move in the history (as a move of the same document, so it can be undone) and saves it; it does not count as
  /// a recent destination.
  ///
  /// Refuses, changing nothing, unless `documentID` is still the file at `currentURL` (see `verifyFiledPlacement`):
  /// `.noHistoryRecord` when the history has no move that left a file there, `.fileChangedSinceFiling` when it has
  /// another document there, and `.fileOperation(.sourceMissing)` or `.fileOperation(.differentItem)` when the file
  /// there is gone or is not the one moved (it was moved, deleted or replaced outside the app). A taken original name
  /// throws `.fileOperation(.nameConflict(existing:))` with `.refuse`; retry with `.keepBoth`.
  func moveBack(
    document documentID: UUID, at currentURL: URL, resolution: ConflictResolution
  ) throws(FilingError) -> MoveOutcome {
    var history = try writableHistory()
    try verifyFiledPlacement(of: documentID, at: currentURL, in: history)
    guard let origin = history.origin(ofDocument: documentID) else {
      throw .noHistoryRecord(currentURL)
    }
    let record: MoveRecord
    do {
      record = try expectedChanges.perform(
        { () throws(FileOperationError) in
          try fileOperations.move(
            currentURL, into: origin.deletingLastPathComponent(), named: origin.lastPathComponent,
            resolution: resolution)
        }, expecting: Self.changes(madeBy:))
    } catch {
      throw .fileOperation(error)
    }
    let event = history.recordMove(record, at: Date())
    self.history = history
    save()
    Logger.filing.notice(
      "Moved \(currentURL.lastPathComponent, privacy: .private) back to \(record.destinationURL.deletingLastPathComponent().lastPathComponent, privacy: .private)"
    )
    return MoveOutcome(event: event, record: record, replacedEvent: nil, status: currentStatus)
  }

  /// Checks that the filed document `documentID` is the file at `url`, before it is moved again: the history has it
  /// there (its latest active event is a move that left it at `url`), and the item on disk is the one that move left.
  ///
  /// Throws `.noHistoryRecord` when the history has no document at `url` or the document's latest event is not a
  /// move, `.fileChangedSinceFiling` when another document is there (a Replace or a later filing took its place), and
  /// `.fileOperation(.sourceMissing)` or `.fileOperation(.differentItem)` when the item on disk is gone or another one.
  private func verifyFiledPlacement(
    of documentID: UUID, at url: URL, in history: FilingHistory
  ) throws(FilingError) {
    guard let documentAtURL = history.document(at: url) else { throw .noHistoryRecord(url) }
    guard documentAtURL == documentID else { throw .fileChangedSinceFiling(url) }
    guard case .moved(let latestMove)? = history.latestActiveEvent(ofDocument: documentID)?.action
    else {
      throw .noHistoryRecord(url)
    }
    // Only the identity of the file at `url` matters here, not an item a Replace sent to the Trash, so the check uses
    // the move without its replaced item.
    let placement = MoveRecord(
      originalURL: latestMove.originalURL, destinationURL: latestMove.destinationURL,
      createdFolders: [], replaced: nil, movedItem: latestMove.movedItem)
    if let blocker = fileOperations.undoBlocker(for: placement) { throw .fileOperation(blocker) }
  }

  /// Puts the file at `trashedURL` in the Trash back where it was, by undoing its trash event (see `undo(eventID:)`),
  /// also after a restart.
  ///
  /// Throws `.noHistoryRecord` when the history has no trash event that left a file at `trashedURL` still active,
  /// and what `undo(eventID:)` throws otherwise.
  func putBack(_ trashedURL: URL) throws(FilingError) -> UndoOutcome {
    let history = try writableHistory()
    guard let documentID = history.document(at: trashedURL),
      let latestEvent = history.latestActiveEvent(ofDocument: documentID),
      case .trashed = latestEvent.action
    else {
      throw .noHistoryRecord(trashedURL)
    }
    return try undo(eventID: latestEvent.id)
  }

  /// Every event of the filing history in the order recorded (oldest first), active and undone; empty while the
  /// history cannot be read.
  func events() -> [FilingEvent] {
    loadIfNeeded()
    return history?.events ?? []
  }

  // MARK: Own changes

  /// The changes `record`'s move made: the file left its place and arrived at its destination (which is in an inbox
  /// for a rename in place, a move into an inbox subfolder or a Move Back), and a Replace removed the item that was
  /// there. The watcher applies each change only to the inbox it lies in, so changes in the archive are ignored.
  private static func changes(madeBy record: MoveRecord) -> [ExpectedChange] {
    var changes: [ExpectedChange] = [
      .removal(of: record.originalURL), .arrival(at: record.destinationURL),
    ]
    if let replaced = record.replaced { changes.append(.removal(of: replaced.originalURL)) }
    return changes
  }

  /// The changes undoing `action` made: the file is back at `restored`, having left its filed place; an item a
  /// Replace sent to the Trash is back at that place.
  private static func changes(
    undoing action: FilingAction, restoredTo restored: RestoredItem
  ) -> [ExpectedChange] {
    switch action {
    case .moved(let record):
      var changes: [ExpectedChange] = [
        .removal(of: record.destinationURL), .arrival(at: restored.url),
      ]
      if let replaced = record.replaced { changes.append(.arrival(at: replaced.originalURL)) }
      return changes
    case .trashed:
      return [.arrival(at: restored.url)]
    }
  }

  // MARK: History file

  /// Tries the pending save again and returns the state.
  func retrySave() -> FilingStatus {
    if pendingSaveError != nil { save() }
    return currentStatus
  }

  /// Saves a pending change one last time before the app quits; `false` when it still fails.
  func saveBeforeQuit() -> Bool {
    if pendingSaveError != nil { save() }
    return pendingSaveError == nil
  }

  /// Sets the unreadable history file aside as `FilingHistory-unreadable-<yyyy-MM-dd-HHmmss>.json` next to it and
  /// starts an empty history.
  func startNewHistory() throws(FilingError) -> FilingStatus {
    loadIfNeeded()
    guard unreadableError != nil else { return currentStatus }
    let fileURL = store.fileURL
    let setAsideURL = fileURL.deletingLastPathComponent().appending(
      path: "FilingHistory-unreadable-\(Self.timestamp(Date())).json", directoryHint: .notDirectory)
    do {
      try FileManager.default.moveItem(at: fileURL, to: setAsideURL)
    } catch {
      Logger.filing.error(
        "Could not set the unreadable filing history aside: \(error.localizedDescription, privacy: .public)"
      )
      throw .setAsideFailed(url: fileURL, reason: error.localizedDescription)
    }
    Logger.filing.notice(
      "Set the unreadable filing history aside as \(setAsideURL.lastPathComponent, privacy: .public) and started a new one"
    )
    unreadableError = nil
    history = FilingHistory()
    return currentStatus
  }

  // MARK: Loading and saving

  private func loadIfNeeded() {
    guard !isLoaded else { return }
    isLoaded = true
    do {
      history = try store.load()
      Logger.filing.notice(
        "Loaded the filing history: \(self.history?.events.count ?? 0, privacy: .public) event(s)")
    } catch {
      unreadableError = error
      Logger.filing.error(
        "The filing history cannot be read; it is left untouched: \(error.description, privacy: .public)"
      )
    }
    do {
      recents = try recentsPreference.load() ?? RecentDestinations()
    } catch {
      // Recents are a convenience: starting from an empty list loses only the ordering, and the next move replaces
      // the unreadable value.
      Logger.filing.error(
        "The recent destinations cannot be read; starting empty: \(error.description, privacy: .public)"
      )
    }
  }

  /// The history to record into, after retrying a pending save; throws while the history cannot be read.
  private func writableHistory() throws(FilingError) -> FilingHistory {
    loadIfNeeded()
    if let unreadableError { throw .historyUnreadable(unreadableError) }
    if pendingSaveError != nil { save() }
    return history ?? FilingHistory()
  }

  /// Saves the history and the recents; a failed history save is kept as `pendingSaveError`.
  private func save() {
    if let history {
      do {
        try store.save(history)
        if pendingSaveError != nil {
          Logger.filing.notice("Saved the filing history after an earlier failure")
        }
        pendingSaveError = nil
      } catch {
        pendingSaveError = error
        Logger.filing.error(
          "Could not save the filing history; keeping the change in memory: \(error.description, privacy: .public)"
        )
      }
    }
    do {
      try recentsPreference.save(recents)
    } catch {
      Logger.filing.error(
        "Could not save the recent destinations: \(error.description, privacy: .public)")
    }
  }

  /// `date` as `yyyy-MM-dd-HHmmss` in the current time zone.
  private static func timestamp(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.dateFormat = "yyyy-MM-dd-HHmmss"
    return formatter.string(from: date)
  }
}
