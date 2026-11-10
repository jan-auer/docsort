import DocsortCore
import Foundation

/// The configured folders the History entries are described against.
nonisolated struct HistoryFolders: Sendable {
  /// One configured inbox.
  struct Inbox: Sendable {
    /// The inbox's display label.
    let label: String
    /// The inbox folder.
    let url: URL
  }

  /// The archive folder, for archive-relative destination paths; `nil` while none is configured.
  let archiveRoot: URL?
  /// The configured inboxes, to name the inbox each file came from.
  let inboxes: [Inbox]
}

/// Turns the filing history into the entries the History window lists, one per event, oldest first.
///
/// UI-free, like the services: it reads the events `FilingService.events()` returns and checks whether each entry's
/// file is still where the entry put it, off the main actor.
nonisolated enum HistoryListing {
  /// The entries for `events` (oldest first), described against `folders`, checking the disk off the main actor.
  @concurrent static func entries(
    from events: [FilingEvent], folders: HistoryFolders
  ) async -> [HistoryEntry] {
    entries(from: events, folders: folders) { url in
      FileManager.default.fileExists(atPath: url.path(percentEncoded: false))
    }
  }

  /// The entries for `events` (oldest first), described against `folders`; `isPresent` says whether something is at
  /// a location.
  ///
  /// An event's file counts as still in place when the event is active, is its document's latest active event, and
  /// something is at its result location. A document's first event decides where it came from: a move out of that
  /// folder files it, a move into it moves it back.
  static func entries(
    from events: [FilingEvent], folders: HistoryFolders, isPresent: (URL) -> Bool
  ) -> [HistoryEntry] {
    var originByDocument: [UUID: URL] = [:]
    var latestActiveByDocument: [UUID: FilingEvent.ID] = [:]
    for event in events {
      if originByDocument[event.documentID] == nil {
        originByDocument[event.documentID] = event.sourceURL
      }
      if event.undoneDate == nil { latestActiveByDocument[event.documentID] = event.id }
    }
    return events.map { event in
      let origin = originByDocument[event.documentID] ?? event.sourceURL
      let inboxName = inboxName(of: origin, in: folders)
      let kind = kind(of: event, originFolder: origin.deletingLastPathComponent())
      let place: HistoryEntryPlace =
        if let undoneDate = event.undoneDate {
          .undone(undoneDate)
        } else if latestActiveByDocument[event.documentID] != event.id
          || !isPresent(event.resultURL)
        {
          .movedOrDeleted
        } else {
          .current
        }
      return HistoryEntry(
        id: event.id, documentID: event.documentID, date: event.date, kind: kind,
        originalName: event.sourceURL.lastPathComponent, inboxName: inboxName,
        newName: kind == .trashed || kind == .replaced ? nil : event.resultURL.lastPathComponent,
        destination: destination(of: event, kind: kind, inboxName: inboxName, folders: folders),
        url: event.resultURL, place: place)
    }
  }

  /// What `event` did, given the folder its document came from.
  private static func kind(of event: FilingEvent, originFolder: URL) -> HistoryEntryKind {
    switch event.action {
    case .trashed:
      return event.causedBy == nil ? .trashed : .replaced
    case .moved:
      let sourceFolder = FileLocation.path(of: event.sourceURL.deletingLastPathComponent())
      let resultFolder = FileLocation.path(of: event.resultURL.deletingLastPathComponent())
      let origin = FileLocation.path(of: originFolder)
      if sourceFolder == resultFolder { return .renamed }
      if sourceFolder == origin { return .filed }
      if resultFolder == origin { return .movedBack }
      return .movedOn
    }
  }

  /// Where `event` put its file, as the user reads it.
  private static func destination(
    of event: FilingEvent, kind: HistoryEntryKind, inboxName: String?, folders: HistoryFolders
  ) -> String {
    switch kind {
    case .trashed, .replaced:
      return "Trash"
    case .movedBack:
      let inbox = inboxName ?? event.resultURL.deletingLastPathComponent().lastPathComponent
      return "\(inbox) (moved back from \(folderName(event.sourceURL, folders: folders)))"
    case .filed, .renamed, .movedOn:
      return folderName(event.resultURL, folders: folders)
    }
  }

  /// The folder holding `url`: archive-relative inside the archive (the archive folder's name for the archive folder
  /// itself), its abbreviated path elsewhere.
  private static func folderName(_ url: URL, folders: HistoryFolders) -> String {
    let folder = url.deletingLastPathComponent()
    if let archiveRoot = folders.archiveRoot,
      let relative = relativePath(of: folder, in: archiveRoot)
    {
      return relative.isEmpty ? archiveRoot.lastPathComponent : relative
    }
    return DisplayPath.abbreviating(FileLocation.path(of: folder))
  }

  /// The label of the configured inbox holding `origin` (the innermost, should inboxes nest); for an origin outside
  /// every inbox, `nil` inside the archive (an archive item) and the folder's name elsewhere (an inbox no longer
  /// configured).
  private static func inboxName(of origin: URL, in folders: HistoryFolders) -> String? {
    if let label = InboxLocation.label(
      ofInboxHolding: origin, among: folders.inboxes.map { ($0.label, $0.url) })
    {
      return label
    }
    if let archiveRoot = folders.archiveRoot, relativePath(of: origin, in: archiveRoot) != nil {
      return nil
    }
    return origin.deletingLastPathComponent().lastPathComponent
  }

  /// `url`'s path relative to `ancestor` (`""` when they are the same folder), or `nil` when it lies outside.
  private static func relativePath(of url: URL, in ancestor: URL) -> String? {
    DestinationIndex.archiveRelativePath(of: url, under: ancestor)
  }
}
