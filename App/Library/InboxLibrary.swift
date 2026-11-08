import DocsortCore
import Foundation
import OSLog
import Observation

/// What happened to an inbox file in this session, with what the filing panel's status strip shows about it.
nonisolated enum InboxItemMark: Hashable, Sendable {
  /// The file was filed (or later renamed or moved on) to `destinationPath` (archive-relative) at `date` and now lies
  /// at `newURL`, as the filing history's document `documentID`. Moving it again requires that document to still be
  /// the one at `newURL`, so the row never acts on a file that took its place.
  case filed(newURL: URL, destinationPath: String, date: Date, documentID: UUID)
  /// The file was moved to the Trash at `date` and lies at `trashedURL` there.
  case trashed(trashedURL: URL, date: Date)

  /// Whether the file was moved to the Trash.
  var isTrashed: Bool {
    if case .trashed = self { true } else { false }
  }

  /// The filing history's document of a filed file; `nil` for a trashed one.
  var filedDocumentID: UUID? {
    if case .filed(_, _, _, let documentID) = self { documentID } else { nil }
  }
}

/// One file row of an inbox section: the file as it was listed and what happened to it in this session.
nonisolated struct InboxRow: Hashable, Sendable, Identifiable {
  /// The file as the inbox scan listed it.
  let item: InboxItem
  /// What happened to the file in this session; `nil` while it is unhandled.
  let mark: InboxItemMark?
  /// Whether the file arrived from outside docsort while the inbox was watched and has not been selected since: the
  /// row shows the "new" dot.
  var isNewArrival = false

  /// The file's identity.
  var id: InboxItemID { InboxItemID(item) }

  /// Where the file is now: its archive location once filed, otherwise its inbox location.
  var currentURL: URL {
    if case .filed(let newURL, _, _, _) = mark { return newURL }
    return item.url
  }

  /// Whether the file is still waiting to be filed.
  var isUnhandled: Bool { mark == nil }
}

/// A subfolder of an inbox with the file rows below it, shown as a disclosure row.
nonisolated struct InboxGroup: Hashable, Sendable, Identifiable {
  /// The subfolder's location, which identifies the group.
  let url: URL
  /// The subfolder's name.
  let name: String
  /// The date that places the group among its siblings.
  let date: Date
  /// The files below the subfolder, in display order.
  var rows: [InboxRow]

  var id: URL { url }
}

/// One top-level entry of an inbox section.
nonisolated enum InboxSectionEntry: Hashable, Sendable, Identifiable {
  /// A file directly in the inbox.
  case row(InboxRow)
  /// A subfolder with its files.
  case group(InboxGroup)

  /// The entry's identity: the file's for a row, the folder's URL for a group.
  var id: String {
    switch self {
    case .row(let row): "row:\(row.id)"
    case .group(let group): "group:\(group.url.path(percentEncoded: false))"
    }
  }

  /// The entry's rows: the file itself, or the group's files.
  var rows: [InboxRow] {
    switch self {
    case .row(let row): [row]
    case .group(let group): group.rows
    }
  }
}

/// Why an inbox cannot be listed.
nonisolated enum InboxProblem: Hashable, Sendable {
  /// Nothing is at the inbox's folder path.
  case folderNotFound(path: String)
  /// The inbox's path names something that is not a folder.
  case notAFolder(path: String)
  /// The folder exists but cannot be read; `reason` is the system's explanation.
  case unreadable(path: String, reason: String)
}

/// What an inbox section shows.
nonisolated enum InboxSectionContent: Hashable, Sendable {
  /// The first scan of the inbox has not finished yet.
  case scanning
  /// The inbox's entries in display order; `problems` lists what the scan could not read.
  case listing([InboxSectionEntry], problems: [ScanProblem])
  /// The inbox cannot be listed.
  case unreachable(InboxProblem)
}

/// A change made outside docsort that the main window follows.
nonisolated enum InboxExternalChange: Hashable, Sendable {
  /// The file `id`, named `name`, was removed from the inbox labelled `inboxLabel`; `next` is the next unhandled row
  /// after it in display order as it was listed, for a selection that has to move.
  case removed(InboxItemID, name: String, inboxLabel: String, next: InboxItemID?)
  /// The file `id` became the file `replacement`: a download completed into a file of its own.
  case replaced(InboxItemID, by: InboxItemID)
}

/// One configured inbox as the sidebar shows it.
nonisolated struct InboxSection: Hashable, Sendable, Identifiable {
  /// The inbox's identity in the folder settings.
  let id: InboxFolder.ID
  /// The inbox's display label.
  let label: String
  /// What the section shows.
  let content: InboxSectionContent

  /// The section's file rows, flattened in display order.
  var rows: [InboxRow] {
    guard case .listing(let entries, _) = content else { return [] }
    return entries.flatMap(\.rows)
  }
}

/// The one owner of the inbox rows the sidebar shows: lists every configured inbox and merges in what happened to
/// its files in this session.
///
/// One per app. It follows a `FolderLibrary`'s inboxes and watches them with an `InboxWatcher`, which scans off the
/// main actor: one subscription for all usable inboxes, started at launch and again whenever the inboxes change and on
/// `refresh()` (⌘R). Each update's listing is the source of truth; its changes (made outside docsort) only annotate
/// it: an arrival shows the "new" dot until the row is first selected (`markSeen`), and removals and completed
/// downloads are reported through `onExternalChange`, so the window can move its selection.
///
/// Files filed or trashed in this session are marked (`setMark`) by `InboxItemID`. A marked file that is no longer on
/// disk keeps its row, in its old place, across rescans (decision `inbox-and-history-behaviour`: the list never
/// shuffles). Removing the mark (for undo, Move Back and Put Back) keeps the row until the next scan finds the file
/// back on disk.
///
/// Like the other libraries it uses only Foundation, Observation and DocsortCore.
@Observable
final class InboxLibrary {
  /// One section per configured inbox, in the settings' order.
  private(set) var sections: [InboxSection] = []

  /// The configured inboxes the sections belong to.
  @ObservationIgnored private var inboxes: [ConfiguredInbox] = []
  /// The latest scan result per inbox.
  @ObservationIgnored private var scans: [InboxFolder.ID: ScanResult] = [:]
  /// Rows to keep showing: marked files, and unmarked ones until the next scan of their inbox.
  @ObservationIgnored private var keptRows: [InboxItemID: KeptRow] = [:]
  /// The rows of `sections` by identity, with the label of their section. Observed like `sections`, so a view that
  /// looks up one row (the selected file) follows its changes.
  private var rowsByID: [InboxItemID: (row: InboxRow, sectionLabel: String)] = [:]
  /// Files that arrived from outside docsort and have not been selected since.
  @ObservationIgnored private var newArrivals: Set<InboxItemID> = []
  /// Called after an update with each removal and completed download made outside docsort, in order.
  @ObservationIgnored var onExternalChange: ((InboxExternalChange) -> Void)?

  @ObservationIgnored private let watcher: InboxWatcher
  /// Counts subscriptions, so an update from a superseded one is ignored.
  @ObservationIgnored private var watchGeneration = 0
  @ObservationIgnored private var watchTask: Task<Void, Never>?
  /// The inboxes of the current subscription that have not had their first update yet.
  @ObservationIgnored private var inboxesAwaitingFirstUpdate: Set<InboxFolder.ID> = []
  @ObservationIgnored private var firstUpdateWaiters: [CheckedContinuation<Void, Never>] = []
  @ObservationIgnored private var observationTask: Task<Void, Never>?

  /// An inbox library that is told its inboxes through `update(inboxes:)` and watches them with `watcher`.
  init(watcher: InboxWatcher = InboxWatcher(expectedChanges: ExpectedChanges())) {
    self.watcher = watcher
  }

  /// An inbox library listing `folders`' inboxes with `watcher`, resubscribing whenever they change.
  convenience init(folders: FolderLibrary, watcher: InboxWatcher) {
    self.init(watcher: watcher)
    observationTask = Task { [weak self] in
      for await inboxes in Observations({ folders.inboxes }) {
        guard let self else { return }
        update(inboxes: inboxes)
      }
    }
  }

  isolated deinit {
    observationTask?.cancel()
    watchTask?.cancel()
    resumeFirstUpdateWaiters()
  }

  // MARK: Watching

  /// Lists and watches `inboxes` from now on, unless they are the inboxes already listed.
  func update(inboxes: [ConfiguredInbox]) {
    guard inboxes != self.inboxes else { return }
    self.inboxes = inboxes
    let ids = Set(inboxes.map(\.id))
    scans = scans.filter { ids.contains($0.key) }
    restartWatching()
  }

  /// Watches every inbox anew, which scans each again (View › Refresh, ⌘R).
  func refresh() {
    restartWatching()
  }

  /// Waits until every inbox of the current subscription has had its first update applied.
  func waitForScan() async {
    guard !inboxesAwaitingFirstUpdate.isEmpty else { return }
    await withCheckedContinuation { firstUpdateWaiters.append($0) }
  }

  /// Ends the current subscription and starts one for the usable inboxes. Until their first updates arrive, the
  /// sections keep their previous listings.
  private func restartWatching() {
    watchTask?.cancel()
    watchGeneration += 1
    let generation = watchGeneration
    var watched: [WatchedInbox] = []
    for inbox in inboxes {
      if let url = inbox.url, inbox.folder.isUsable {
        watched.append(WatchedInbox(id: inbox.id, folder: url))
      } else {
        scans[inbox.id] = .failed(Self.problem(for: inbox.folder))
      }
    }
    inboxesAwaitingFirstUpdate = Set(watched.map(\.id))
    rebuildSections()
    if inboxesAwaitingFirstUpdate.isEmpty { resumeFirstUpdateWaiters() }
    let updates = watcher.updates(for: watched)
    watchTask = Task { [weak self] in
      for await update in updates {
        guard let self else { return }
        apply(update, generation: generation)
      }
    }
  }

  private func resumeFirstUpdateWaiters() {
    let waiters = firstUpdateWaiters
    firstUpdateWaiters = []
    for waiter in waiters { waiter.resume() }
  }

  /// Applies `update`, unless its subscription has been superseded.
  private func apply(_ update: InboxUpdate, generation: Int) {
    guard generation == watchGeneration, !Task.isCancelled else {
      Logger.inbox.debug("Ignoring an inbox update from a superseded subscription")
      return
    }
    let id = update.inboxID
    guard let inbox = inboxes.first(where: { $0.id == id }) else { return }
    let rowsBefore = orderedRows
    let externalChanges = annotate(
      update.changes, inboxLabel: inbox.displayLabel, rowsBefore: rowsBefore)
    switch update.state {
    case .listed(let listing): scans[id] = .listed(listing)
    case .unreachable(let error): scans[id] = .failed(Self.problem(for: error))
    }
    // The update shows what is on disk now; rows kept only for an undo are no longer needed.
    keptRows = keptRows.filter { $0.value.sectionID != id || $0.value.mark != nil }
    rebuildSections()
    if inboxesAwaitingFirstUpdate.remove(id) != nil, inboxesAwaitingFirstUpdate.isEmpty {
      resumeFirstUpdateWaiters()
    }
    Logger.inbox.notice(
      "Updated inbox \(inbox.displayLabel, privacy: .private): \(self.sections.first { $0.id == id }?.rows.count ?? 0, privacy: .public) row(s), \(update.changes.count, privacy: .public) external change(s)"
    )
    for change in externalChanges { onExternalChange?(change) }
  }

  /// Records what `changes` (made outside docsort) mean for the rows, and returns the changes the window follows.
  private func annotate(
    _ changes: [InboxChange], inboxLabel: String, rowsBefore: [InboxRow]
  ) -> [InboxExternalChange] {
    let removedIDs: Set<InboxItemID> = Set(
      changes.compactMap { change in
        if case .removed(let item) = change { InboxItemID(item) } else { nil }
      })
    var externalChanges: [InboxExternalChange] = []
    for change in changes {
      switch change {
      case .arrived(let item):
        let arrivedID = InboxItemID(item)
        newArrivals.insert(arrivedID)
        // A handled file brought back by someone else (Put Back in Finder) is unhandled again.
        keptRows[arrivedID] = nil
      case .removed(let item):
        let removedID = InboxItemID(item)
        newArrivals.remove(removedID)
        let next = Self.nextUnhandledRow(after: removedID, in: rowsBefore) {
          !removedIDs.contains($0.id)
        }
        externalChanges.append(
          .removed(removedID, name: item.name, inboxLabel: inboxLabel, next: next?.id))
      case .changed(let old, let new):
        let oldID = InboxItemID(old)
        let newID = InboxItemID(new)
        guard oldID != newID else { continue }
        if newArrivals.remove(oldID) != nil { newArrivals.insert(newID) }
        externalChanges.append(.replaced(oldID, by: newID))
      }
    }
    return externalChanges
  }

  /// The outcome of scanning one inbox.
  private enum ScanResult: Sendable {
    case listed(InboxListing)
    case failed(InboxProblem)
  }

  // MARK: Marks

  /// Sets what happened to the file `id` in this session: `mark`, or, for `nil`, nothing (after an undo, Move Back or
  /// Put Back returned it to its inbox). An unmarked row stays until the next scan of its inbox.
  func setMark(_ id: InboxItemID, _ mark: InboxItemMark?) {
    guard let mark else {
      guard keptRows[id] != nil else { return }
      keptRows[id]?.mark = nil
      rebuildSections()
      return
    }
    if keptRows[id] == nil {
      guard let kept = keptRow(for: id) else {
        Logger.inbox.error("Cannot mark \(id, privacy: .private): no such row")
        return
      }
      keptRows[id] = kept
    }
    keptRows[id]?.mark = mark
    rebuildSections()
  }

  // MARK: Lookup

  /// The row of the file `id`, or `nil` when no section lists it.
  func row(for id: InboxItemID) -> InboxRow? {
    rowsByID[id]?.row
  }

  /// The rows marked as filed as the filing history's document `documentID`, in display order.
  func rowIDs(filedAs documentID: UUID) -> [InboxItemID] {
    orderedRows.filter { $0.mark?.filedDocumentID == documentID }.map(\.id)
  }

  /// The row listing the inbox file at `url`, or `nil` when no section lists one there.
  func row(listing url: URL) -> InboxRow? {
    let path = url.standardizedFileURL.path(percentEncoded: false)
    return orderedRows.first { $0.item.url.standardizedFileURL.path(percentEncoded: false) == path }
  }

  /// The label of the section listing the file `id`.
  func sectionLabel(of id: InboxItemID) -> String? {
    rowsByID[id]?.sectionLabel
  }

  /// Every row of every section, in display order.
  var orderedRows: [InboxRow] {
    sections.flatMap(\.rows)
  }

  /// The next unhandled row after the file `id` in display order, wrapping from the last section to the first;
  /// `nil` when there is none other than `id`.
  func nextUnhandledRow(after id: InboxItemID) -> InboxRow? {
    Self.nextUnhandledRow(after: id, in: orderedRows) { _ in true }
  }

  /// The next unhandled row of `rows` after the file `id` that `isEligible`, wrapping around; the first such row when
  /// `rows` does not hold `id`.
  private static func nextUnhandledRow(
    after id: InboxItemID, in rows: [InboxRow], where isEligible: (InboxRow) -> Bool
  ) -> InboxRow? {
    guard let index = rows.firstIndex(where: { $0.id == id }) else {
      return rows.first { $0.isUnhandled && isEligible($0) }
    }
    let following = rows[(index + 1)...] + rows[..<index]
    return following.first { $0.isUnhandled && isEligible($0) }
  }

  // MARK: New arrivals

  /// Clears the "new" dot of the file `id`, once it is selected.
  func markSeen(_ id: InboxItemID) {
    guard newArrivals.remove(id) != nil else { return }
    rebuildSections()
  }

  /// The first row of the section at `index` (0-based), or `nil` when there is no such section or it has no rows.
  func firstRow(inSection index: Int) -> InboxRow? {
    guard sections.indices.contains(index) else { return nil }
    return sections[index].rows.first
  }

  // MARK: Building the sections

  /// A row kept across scans, with where it was listed.
  private struct KeptRow {
    let sectionID: InboxFolder.ID
    let item: InboxItem
    /// The group the row was listed in, without its rows.
    let group: InboxGroup?
    var mark: InboxItemMark?
  }

  /// The kept-row record for the row `id` as currently listed.
  private func keptRow(for id: InboxItemID) -> KeptRow? {
    for section in sections {
      guard case .listing(let entries, _) = section.content else { continue }
      for entry in entries {
        switch entry {
        case .row(let row) where row.id == id:
          return KeptRow(sectionID: section.id, item: row.item, group: nil, mark: row.mark)
        case .group(let group):
          if let row = group.rows.first(where: { $0.id == id }) {
            var emptyGroup = group
            emptyGroup.rows = []
            return KeptRow(
              sectionID: section.id, item: row.item, group: emptyGroup, mark: row.mark)
          }
        case .row:
          continue
        }
      }
    }
    return nil
  }

  private func rebuildSections() {
    sections = inboxes.map { inbox in
      InboxSection(id: inbox.id, label: inbox.displayLabel, content: content(of: inbox.id))
    }
    var index: [InboxItemID: (row: InboxRow, sectionLabel: String)] = [:]
    for section in sections {
      for row in section.rows {
        index[row.id] = (row, section.label)
      }
    }
    rowsByID = index
  }

  /// The content of the section for inbox `id`: its latest scan with the kept rows merged in.
  private func content(of id: InboxFolder.ID) -> InboxSectionContent {
    switch scans[id] {
    case nil:
      return .scanning
    case .failed(let problem):
      return .unreachable(problem)
    case .listed(let listing):
      var entries = listing.entries.map(entry(for:))
      let listedIDs = Set(listing.items.map(InboxItemID.init))
      let missing = keptRows.values
        .filter { $0.sectionID == id && !listedIDs.contains(InboxItemID($0.item)) }
        .sorted { Self.precedes($0.item, $1.item) }
      for kept in missing {
        insert(kept, into: &entries)
      }
      return .listing(entries, problems: listing.problems)
    }
  }

  private func entry(for entry: InboxEntry) -> InboxSectionEntry {
    switch entry {
    case .item(let item):
      return .row(row(for: item))
    case .subfolder(let subfolder):
      return .group(
        InboxGroup(
          url: subfolder.url, name: subfolder.name, date: subfolder.date,
          rows: subfolder.items.map(row(for:))))
    }
  }

  private func row(for item: InboxItem) -> InboxRow {
    let id = InboxItemID(item)
    return InboxRow(item: item, mark: keptRows[id]?.mark, isNewArrival: newArrivals.contains(id))
  }

  /// Puts a kept row that the scan no longer lists back where it was: into its group (recreating the group when the
  /// scan no longer lists it), placed by date and name as the scan orders entries.
  private func insert(_ kept: KeptRow, into entries: inout [InboxSectionEntry]) {
    let row = InboxRow(item: kept.item, mark: kept.mark)
    guard let group = kept.group else {
      let position =
        entries.firstIndex { Self.precedes(row.item, $0) } ?? entries.endIndex
      entries.insert(.row(row), at: position)
      return
    }
    if let groupIndex = entries.firstIndex(where: {
      if case .group(let listed) = $0 { listed.url == group.url } else { false }
    }), case .group(var listed) = entries[groupIndex] {
      let position =
        listed.rows.firstIndex { Self.precedes(row.item, $0.item) } ?? listed.rows.endIndex
      listed.rows.insert(row, at: position)
      entries[groupIndex] = .group(listed)
      return
    }
    var recreated = group
    recreated.rows = [row]
    let position =
      entries.firstIndex { Self.precedes(date: group.date, name: group.name, $0) }
      ?? entries.endIndex
    entries.insert(.group(recreated), at: position)
  }

  /// Whether `item` sorts before `other`: older first, then in Finder name order, as the inbox scan orders items.
  private static func precedes(_ item: InboxItem, _ other: InboxItem) -> Bool {
    precedes(
      date: item.modificationDate, name: item.name, otherDate: other.modificationDate,
      otherName: other.name)
  }

  /// Whether `item` sorts before the entry `entry`.
  private static func precedes(_ item: InboxItem, _ entry: InboxSectionEntry) -> Bool {
    precedes(date: item.modificationDate, name: item.name, entry)
  }

  /// Whether an entry dated `date` and named `name` sorts before `entry`.
  private static func precedes(date: Date, name: String, _ entry: InboxSectionEntry) -> Bool {
    switch entry {
    case .row(let row):
      precedes(
        date: date, name: name, otherDate: row.item.modificationDate, otherName: row.item.name)
    case .group(let group):
      precedes(date: date, name: name, otherDate: group.date, otherName: group.name)
    }
  }

  private static func precedes(date: Date, name: String, otherDate: Date, otherName: String)
    -> Bool
  {
    if date != otherDate { return date < otherDate }
    return name.localizedStandardCompare(otherName) == .orderedAscending
  }

  // MARK: Problems

  /// Why the configured `folder` cannot be scanned.
  private static func problem(for folder: ResolvedFolder) -> InboxProblem {
    switch folder.availability {
    case .unreachable(let reason):
      .unreadable(path: folder.displayPath, reason: reason)
    case .available, .stale, .missing:
      .folderNotFound(path: folder.displayPath)
    }
  }

  /// Why a scan failed.
  nonisolated private static func problem(for error: FolderAccessError) -> InboxProblem {
    switch error {
    case .notFound(let url):
      .folderNotFound(path: DisplayPath.abbreviating(url.path(percentEncoded: false)))
    case .notAFolder(let url):
      .notAFolder(path: DisplayPath.abbreviating(url.path(percentEncoded: false)))
    case .unreadable(let url, let reason):
      .unreadable(path: DisplayPath.abbreviating(url.path(percentEncoded: false)), reason: reason)
    }
  }

  #if DEBUG
    /// A library showing `sections` as given, for SwiftUI previews; nothing is scanned.
    static func preview(sections: [InboxSection]) -> InboxLibrary {
      let library = InboxLibrary()
      library.sections = sections
      for section in sections {
        for row in section.rows {
          library.rowsByID[row.id] = (row, section.label)
        }
      }
      return library
    }
  #endif
}
