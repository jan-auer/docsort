# Architecture

The target structure of docsort-ui: layers, core services and their interfaces, the concurrency model, and where new
code goes. Signatures are the intended shape, not code to copy; names may still change in review. Decision
`layering` in `docs/decisions.md` sets the rule: build a usable app first, keep new services UI-free so they can
move, and do the full cleanup once the app works end to end. Each section therefore says what to **set now** (cheap
now, costly later) and what to **move later** (during the cleanup).

## Layers

```
App (SwiftUI target "Docsort", default isolation MainActor)
  Views ─────────► View models (@Observable, main actor) ─────────► Core services (actors)
  AppKit bridges (PDFKit, Quick Look, NSOpenPanel, NSWorkspace)          │
                                                                         ▼
Core (Packages/DocsortCore, nonisolated by default)               Building blocks (Sendable values and structs):
                                                                  FileOperations, FilingHistory(+Store),
                                                                  InboxScanner, DestinationIndex, FolderResolver,
                                                                  RecentDestinations, StoredPreference, FolderWatcher
```

- Dependencies point down only: views → view models → core services → building blocks. The core never imports
  SwiftUI or AppKit and knows nothing of views, windows, focus, selection or user-facing strings.
- The core may use Apple's non-UI frameworks when a service needs them (CoreServices for FSEvents; later PDFKit's
  `PDFDocument` text, Vision, Spotlight metadata for suggestions). This widens "Foundation only" in the module doc;
  the hub confirms it before the first such import.
- Only services are called by the app. Building blocks stay public for tests and for the services, but app code
  should not combine them (for example call `FileOperations.move` and then `FilingHistory.recordMove`): that
  combination is a service's job.
- Services depend on each other in one direction only: `FilingService` and `FolderAccessService` depend on no
  other service; `InboxService`, `DestinationService` and `FolderContentsService` read them. No cycles.
- One composition root: `AppEnvironment` (already on the app-ui branch) grows into the place that builds every
  service once per process and hands them to the view models. No service is a global or a singleton.

## What the app layer holds

- **Views**: layout, focus, keyboard handling, accessibility. No file I/O, no history, no orchestration.
- **View models** (`@Observable`, main actor): what the views show, derived from service snapshots, plus pure UI
  state (selection, expansion, focus stop, filter text, the "new" dot until first selected, the bottom-bar message).
  They call one service method per user intent and apply the result. They turn typed core errors into text.
- **AppKit bridges**: `NSViewRepresentable` wrappers (`PDFView`, `QLPreviewView`), panels (`NSOpenPanel`), and
  `NSWorkspace` open/reveal. A bridge may load what it renders (a `PDFDocument`) off the main actor.
- Not in the app: scanning, index building, moves, trash, undo, history load/save, recents bookkeeping, deciding
  whether a disappeared file was moved by the app, bookmark creation and resolution logic beyond calling a service.

## Concurrency model

- Core types are nonisolated (package default) and `Sendable`. Building blocks are synchronous and may block on
  disk; they are only called from a service actor or a `@concurrent` function, never on the main actor.
- Each service is an `actor` and owns its mutable state. Services never touch the main actor.
- **Commands** are `async throws(TypedError)` methods returning a result value. The caller applies the result; the
  service never reaches back into a view model.
- **Live state** is published as snapshots: `func updates() -> AsyncStream<Snapshot>` yields the current snapshot
  first, then every new one (`.bufferingNewest(1)`), so a slow consumer only ever sees the latest. Snapshots are whole
  values (a whole inbox section, a whole catalog), never diffs; the UI diffs by stable IDs.
- A view model consumes a stream in one `Task` it owns (`for await snapshot in service.updates()`), assigns on the main
  actor, and cancels the task in `isolated deinit`.
- Superseded work is cancelled: a new request (a changed archive root, a newer scan) cancels the old task, and its
  result is dropped when it arrives late (`ArchiveLibrary` already does this).
- Ordering between services goes through actor calls, not timing. The rule that matters: a service that must know
  about the app's own file changes asks `FilingService` *after* its own disk read (see Inbox listing).

## Core services

### Folder access (settings, bookmarks, status)

Owns the stored `FolderSettings`, the `FolderResolver`, and the live `FolderAccessSession` (and so every security
scope). Resolving can block on unmounted volumes, so it runs off the main actor.

```swift
public actor FolderAccessService {
  public init(preference: StoredPreference<FolderSettings>, resolver: FolderResolver)
  public func updates() -> AsyncStream<FolderAccessState>
  public func setArchiveRoot(_ url: URL) throws(FolderEditError)
  public func addInbox(_ url: URL, label: String?) throws(FolderEditError)
  public func replaceFolder(ofInbox id: InboxFolder.ID, with url: URL) throws(FolderEditError)
  public func removeInbox(_ id: InboxFolder.ID) throws(FolderEditError)
  public func relabelInbox(_ id: InboxFolder.ID, to label: String?) throws(FolderEditError)
  public func moveInboxes(fromOffsets: IndexSet, toOffset: Int) throws(FolderEditError)
  public func resetSettings()
}
public struct FolderAccessState: Sendable {   // archiveRoot: ResolvedFolder?, inboxes: [ResolvedInbox],
}                                             // settingsReadError: PreferenceError?
```

- Set now: nothing; `FolderLibrary` on the app-ui branch already keeps this logic UI-free in one file.
- Move later: `FolderLibrary`'s load → resolve → save-renewed → edit logic into this actor; `FolderLibrary` becomes a
  thin view model; alert text moves into the view model, typed errors into the core.

### Filing (perform → record → save, undo, history)

The only owner of `FileOperations`, `FilingHistory` and `FilingHistoryStore`. Every command is perform → record →
save inside one actor call, so the history never falls behind the disk (decision `history-save-failure`).

```swift
public actor FilingService {
  public init(store: FilingHistoryStore, operations: FileOperations, now: @Sendable () -> Date)
  public func updates() -> AsyncStream<FilingState>
  public func file(_ source: URL, into folder: URL, named name: String, resolution: ConflictResolution)
    throws(FilingError) -> FilingOutcome
  public func trash(_ item: URL) throws(FilingError) -> FilingOutcome
  public func undo(_ event: FilingEvent.ID, resolution: UndoConflictResolution) throws(FilingError) -> FilingOutcome
  public func moveBack(document documentID: UUID, resolution: UndoConflictResolution)
    throws(FilingError) -> FilingOutcome    // back to the document's inbox origin
  public func undoBlocker(for event: FilingEvent.ID) -> FilingError?   // history and disk checks, no side effects
  public func handledItems(in inbox: URL) -> [HandledItem]             // this session's filed/trashed inbox files
  public func retrySave() throws(FilingHistoryStoreError)
  public func startNewHistory() throws(FilingHistoryStoreError)       // renames the unreadable file aside
}
public struct FilingOutcome: Sendable {   // events: [FilingEvent] (a Replace yields two), restored item if any,
}                                         // pendingSaveError: FilingHistoryStoreError?
public struct FilingState: Sendable {     // history: FilingHistory, availability: .ready | .historyUnreadable(reason),
}                                         // pendingSaveError: FilingHistoryStoreError?
public struct HandledItem: Sendable {     // originalURL, currentURL, handling: .filed(event) | .trashed(event)
}
```

- History-save policy: a failed save keeps the change and sets `pendingSaveError` in the outcome and the state;
  every later command retries the save first; at quit the app calls `retrySave()` and shows "Quit Anyway / Cancel" on
  failure. An unreadable history at launch sets `.historyUnreadable` and every command throws until
  `startNewHistory()`.
- `handledItems(in:)` is what the inbox listing uses to keep the app's own moves checked off in place. It is derived
  from this session's events, so it needs no separate bookkeeping anywhere else.
- Renaming a filed file, moving it on, and Revert name are all `file(_:into:named:)` from its current place; the
  pre-filing name comes from `HandledItem.originalURL`. No separate rename command.
- Target: recents are recorded by the destination service from the outcome stream (see below). Until the cleanup,
  `FilingService` may record them itself.
- Name checks stay pure functions in the core (`FileNaming`); the conflict check while typing
  (`existingItem(named:in:)`) is a read and may be called through `FilingService` or a `@concurrent` function.
- Set now: `FilingService` returns values and holds no UI types; keep it in its own file under `App/Library/`.
- Move later: the actor into `Packages/DocsortCore/Filing/`; its tests move with it.

### Inbox listing with live updates

Owns one section per configured inbox: the watcher, the scanner, and merging in the rows the app handled. The
folder-watch branch builds the watcher half (`InboxWatcher`, `ExpectedChanges`); this is where it ends up.

```swift
public actor InboxService {
  public init(folders: FolderAccessService, filing: FilingService, watcher: InboxWatcher)
  public func updates() -> AsyncStream<[InboxSection]>
  public func rescan(_ inbox: InboxFolder.ID?)                  // ⌘R; nil rescans all
}
public struct InboxSection: Sendable, Identifiable {             // id: InboxFolder.ID, label,
}                                                               // content: .scanning | .rows([InboxRow]) | .unreachable(FolderAccessError)
public struct InboxRow: Sendable, Identifiable {                 // id: stable across renames (FileIdentity-based),
}                                                               // item or group, handling: .filed | .trashed | nil, arrivedLive: Bool
```

- **Rescan, not patch.** Each coalesced FSEvents batch rescans the affected inbox with `InboxScanner` (which owns
  order and grouping) and diffs old against new by identity, then path, then the download-name rule.
- **Own versus external changes**: `FilingService` runs every move, trash and undo through `ExpectedChanges.perform`,
  which holds the watcher's diffs while the operation runs and leaves the operation's own changes out of the next
  diff. Only `FilingService` sees `ExpectedChanges`; `FileOperations` stays pure and the UI never registers anything.
- **Handled rows**: a filed or trashed file is gone from the scan but keeps its row, checked off, in its old place.
  The rows come from `FilingService.handledItems(in:)`, this session's events, not from a second list in the UI.
- **Stable row identity**: `InboxItem` carries its `FileIdentity`; a row's ID survives a rename in place and a
  completed download. The sidebar selection, the filing panel and the preview key on the row ID, not the URL.
- The event source and coalescer are reusable for watching the archive later.
- Set now: rows and selection keyed on identity; `ExpectedChanges` used only inside `FilingService`.
- Move later: merging handled rows into the listing (done in the app's `InboxLibrary` until then) into `InboxService`.

### Destination lookup and search

Owns the archive index, recents and the ranking setting, and publishes them as one value the picker can search
synchronously on every keystroke.

```swift
public actor DestinationService {
  public init(folders: FolderAccessService, filing: FilingService,
              recents: StoredPreference<RecentDestinations>, ranking: StoredPreference<ScopedRanking>)
  public func updates() -> AsyncStream<DestinationCatalogState>   // .unavailable | .indexing | .ready(DestinationCatalog) | .failed(reason)
  public func setRanking(_ ranking: ScopedRanking)
}
public struct DestinationCatalog: Sendable {   // index: DestinationIndex, recents: RecentDestinations, ranking: ScopedRanking
  public func search(_ query: String, in scope: String) -> [DestinationMatch]
  public func browse(_ scope: String) -> DestinationListing   // recents (at the root) + subfolders, for an empty filter
  public func url(for path: String) -> URL
}
```

- Recents: the service consumes `FilingService` outcomes, records the destination's archive-relative path and
  saves; it rebuilds the index when a move created folders (or when the archive watcher reports a change).
- Suggestions later add a boost input next to recents (`search(_:in:boosting:)`), not a second search path.
- Now: the picker model (`App/Picker/`) takes `index`, `recents` and `ranking` as separate inputs and reports
  through `onEvent`. Fine until the cleanup, when the three inputs become one `DestinationCatalog`.
- Move later: `ArchiveLibrary`'s build/cancel logic and `SearchSettings` into this actor; the ranking preference key
  next to the others (`ScopedRanking.preference(in:)`); symlink classification into `ScanProblem` (the walker knows
  it skipped a link).

### Folder contents and previews

```swift
public actor FolderContentsService {
  public func files(in folder: URL) throws(FolderAccessError) -> [FolderFile]   // cached per folder
  public func invalidate(_ folder: URL)
}
public struct FileFacts: Sendable {   // name, content type, size, dates; read with one stat
  public static func read(_ url: URL) throws -> FileFacts
}
```

- Folder contents are cached by folder URL and invalidated by `FilingService` outcomes and the archive watcher. Only
  this listing pays for a cache: the picker moves its highlight quickly over the same folders.
- `DestinationIndex.files(in:)` is a folder listing, not part of the tree index; it moves here.
- The picker's `FolderFileListing` protocol is this service's seam today; it becomes `FolderContentsService`.
- Previews render in the app (PDFKit, Quick Look are UI). A `PreviewLoader` in `App/Preview/` loads documents off the
  main actor and may keep a small cache (the current and the next unfiled file). Views ask the loader; they do not
  load files themselves.
- Move later: `PreviewFileInfo` becomes core `FileFacts`; the loading in `PreviewView` moves into `PreviewLoader`.

## Where new kinds of code go

| Kind of code | Place |
| --- | --- |
| A new user action on files or history | A command on `FilingService` |
| Anything read from disk to show | A core service or building block; called off the main actor |
| Caching of disk reads | Inside the service that owns the data, invalidated by outcomes and watcher batches |
| Suggestions (PDF text, OCR, download source) | `Packages/DocsortCore/Suggestions/`: a `SuggestionService` actor taking a file URL and the `DestinationCatalog`, returning destination and name suggestions; extraction parts as building blocks |
| Ranking changes | `DestinationMatcher`, behind `DestinationCatalog.search` |
| A new preference | A `StoredPreference` defined next to its type in the core, owned by the service that uses it |
| AppKit or SwiftUI | App only: views, view models, bridges |

## The cleanup, in order

Once the app works end to end: 1. `FilingService` into the core. 2. `FolderAccessService`. 3. `DestinationService`
with recents and ranking. 4. `InboxService` with the watcher. 5. `FolderContentsService`, `FileFacts`,
`PreviewLoader`. Each is one reviewable step that moves logic without changing behaviour; its tests move with it.
