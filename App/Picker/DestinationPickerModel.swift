import DocsortCore
import Foundation
import OSLog
import Observation

/// All state and every intent of the destination picker; see ``PickerContract`` for how the filing panel uses it and
/// `docs/design/ux.md` ("Destination picker") for the behaviour.
///
/// The model never touches the disk itself: it lists folders from ``index`` and reads files through the
/// ``FolderFileListing`` it was created with.
///
/// While a new folder is being named (``newFolderDraft``), the new-folder row's own intents apply
/// (``newFolderName``, ``confirmNewFolder()``, ``cancelNewFolder()``); ``escape()``, ``stepBack()`` and
/// ``requestMove()`` act on the row, and any other intent cancels it first.
@Observable
final class DestinationPickerModel {
  // MARK: Inputs

  /// The archive's folders, `nil` while it is being built. Setting a new one keeps the highlight and the chosen
  /// destination where their folders still exist, turns pending folders that now exist into ordinary ones, and moves
  /// a scope that no longer exists to its nearest existing ancestor.
  var index: DestinationIndex? {
    didSet { indexDidChange() }
  }

  /// Whether the archive index is being rebuilt while ``index`` stays in use; the footer's refresh button shows
  /// progress meanwhile.
  var isRebuildingIndex = false

  /// The recent destinations, most recent first.
  var recents: RecentDestinations {
    didSet { update(highlight: .keep) }
  }

  /// The user's "Rank first" setting for search.
  var ranking: ScopedRanking {
    didSet { update(highlight: .keep) }
  }

  /// Receives the picker's events; set it once, when the panel creates the model.
  @ObservationIgnored var onEvent: (PickerEvent) -> Void = { _ in }

  // MARK: State

  /// The folder the picker is in, `""` for the archive root.
  private(set) var scope = ""

  /// The filter the list is computed from. While a destination is chosen it keeps the filter the destination was
  /// chosen from (the field shows the token instead), so the list does not change under the token.
  private var query = ""

  /// The sections the list shows, recomputed whenever an input or the state changes.
  private(set) var sections: [PickerSection] = []

  /// The id of the highlighted row; `nil` only when no row is selectable.
  private(set) var highlightedRowID: PickerRow.ID?

  /// The chosen destination, `nil` until the user chooses one.
  private(set) var destination: PickerDestination?

  /// New folders the user named that do not exist on disk yet, in the order they were named.
  private(set) var pendingFolders: [String] = []

  /// The new folder being named in the inline row, `nil` when none is. While it is set, the picker is in its parent
  /// with an empty filter and nothing chosen.
  private(set) var newFolderDraft: NewFolderDraft?

  /// The state ``cancelNewFolder()`` returns to.
  @ObservationIgnored private var stateBeforeDraft: StateBeforeDraft?

  /// The files Folder contents shows; follows ``destination``, else the highlighted folder row.
  private(set) var contents: FolderContents = .none

  /// The running listing of ``contents``, if any; tests await it.
  @ObservationIgnored private(set) var contentsTask: Task<Void, Never>?

  /// The folder ``contents`` was last loaded for; `nil` forces the next ``followContents()`` to reload.
  @ObservationIgnored private var contentsTarget: ContentsTarget?

  /// Counts listings started, so a result that arrives after a newer listing started is dropped.
  @ObservationIgnored private var contentsLoadNumber = 0

  private let folderFiles: any FolderFileListing

  /// A picker at the archive root with nothing chosen.
  init(
    folderFiles: any FolderFileListing, index: DestinationIndex? = nil,
    recents: RecentDestinations = RecentDestinations(), ranking: ScopedRanking = .directChildFirst
  ) {
    self.folderFiles = folderFiles
    self.index = index
    self.recents = recents
    self.ranking = ranking
    update(highlight: .first)
  }

  // MARK: Derived state

  /// The text of the filter field, bound to it. Empty while a destination is chosen (the field shows
  /// ``chosenToken``); typing then un-chooses the destination without restoring the earlier filter.
  var filterText: String {
    get { destination == nil ? query : "" }
    set { changeFilter(to: newValue) }
  }

  /// All rows of all sections, in display order.
  var rows: [PickerRow] { sections.flatMap(\.rows) }

  /// The highlighted row, if any.
  var highlightedRow: PickerRow? {
    guard let highlightedRowID else { return nil }
    return rows.first { $0.id == highlightedRowID }
  }

  /// The folder under the highlight, for Tab, Return and ⌘Return: a folder row's folder or the "this folder" row's;
  /// `nil` otherwise. The create row is not one: a typo must never become a folder with a single key, so only
  /// ⇧⌘N or a click confirms it (``confirmCreateRow()``).
  var highlightedDestination: PickerDestination? {
    guard let highlightedRow else { return nil }
    switch highlightedRow.kind {
    case .currentFolder(let path):
      return destination(for: path)
    case .folder(let folder):
      return destination(for: folder.path)
    case .createFolder, .newFolderDraft, .indexing:
      return nil
    }
  }

  /// The folder the highlighted create row would create (not yet pending); `nil` when the create row is not
  /// highlighted or its name is invalid.
  private var highlightedCreateRowDestination: PickerDestination? {
    guard case .createFolder(let name, let parent, let problem) = highlightedRow?.kind,
      problem == nil
    else { return nil }
    return NewFolderPath(typed: name).resolved(
      under: parent, index: index, pendingFolders: pendingFolders)
  }

  /// The path bar's segments: `Archive`, then each segment of the scope; empty at the root.
  var pathBarSegments: [PathBarSegment] {
    guard !scope.isEmpty else { return [] }
    var segments = [PathBarSegment(title: ArchivePath.rootTitle, path: "")]
    var path = ""
    for name in ArchivePath.segments(of: scope) {
      path = ArchivePath.joining(path, name)
      segments.append(PathBarSegment(title: name, path: path))
    }
    return segments
  }

  /// The scope's own name, for the chip "in Gesundheit"; `nil` at the root.
  var scopeTitle: String? {
    scope.isEmpty ? nil : ArchivePath.title(of: scope)
  }

  /// Whether the archive is still being indexed (``index`` is `nil`).
  var isIndexing: Bool { index == nil }

  /// The filter field's placeholder: "Indexing archive…", "Search archive" or "Search in Gesundheit".
  var filterPlaceholder: String {
    if isIndexing { return "Indexing archive…" }
    guard let scopeTitle else { return "Search archive" }
    return "Search in \(scopeTitle)"
  }

  /// The folder ``beginNewFolder()`` would create a folder in, for the button's tooltip "New Folder in Reisen":
  /// ``ArchivePath/rootTitle`` for the root.
  var newFolderParentTitle: String {
    ArchivePath.title(of: newFolderParent)
  }

  /// The chosen destination as the field shows it, `nil` when none is chosen.
  var chosenToken: ChosenToken? {
    guard let destination else { return nil }
    let text = ArchivePath.segments(of: destination.path).joined(separator: " › ")
    if case .newFolder = destination { return ChosenToken(text: text, isNew: true) }
    return ChosenToken(text: text, isNew: false)
  }

  // MARK: Highlight

  /// Moves the highlight `offset` selectable rows down (negative: up), stopping at the first and last row. A chosen
  /// destination is un-chosen first, which highlights its row.
  func moveHighlight(by offset: Int) {
    cancelNewFolder()
    unchooseRestoringFilter()
    let selectable = rows.filter(\.isSelectable)
    guard !selectable.isEmpty else { return }
    let current = selectable.firstIndex { $0.id == highlightedRowID } ?? 0
    let target = min(max(current + offset, 0), selectable.count - 1)
    highlightedRowID = selectable[target].id
    followContents()
  }

  /// Highlights the row with `id` (a click), un-choosing a chosen destination first.
  func highlight(_ id: PickerRow.ID) {
    cancelNewFolder()
    unchooseRestoringFilter()
    guard rows.contains(where: { $0.id == id && $0.isSelectable }) else { return }
    highlightedRowID = id
    followContents()
  }

  // MARK: Choosing

  /// Chooses the highlighted row (Tab, Return) and emits ``PickerEvent/chose(_:)``. With a destination already
  /// chosen, emits it again so the panel moves on to the name field.
  func chooseHighlighted() {
    cancelNewFolder()
    if let destination {
      onEvent(.chose(destination))
      return
    }
    guard let chosen = highlightedDestination else { return }
    choose(chosen)
    onEvent(.chose(chosen))
  }

  /// ⌘Return: moves the file now. Confirms a new folder being named (see ``confirmNewFolderAndMove()``), else uses
  /// the chosen destination, else chooses the highlighted row first (without emitting ``PickerEvent/chose(_:)``);
  /// emits ``PickerEvent/moveRequested(_:)``. Does nothing when there is nothing to choose.
  func requestMove() {
    if newFolderDraft != nil {
      confirmNewFolderAndMove()
      return
    }
    if let destination {
      onEvent(.moveRequested(destination))
      return
    }
    guard let chosen = highlightedDestination else { return }
    choose(chosen)
    onEvent(.moveRequested(chosen))
  }

  /// Opens a row (double-click): steps into a folder with subfolders, chooses anything else.
  func activate(_ id: PickerRow.ID) {
    highlight(id)
    guard highlightedRowID == id else { return }
    if case .folder(let folder) = highlightedRow?.kind, folder.hasSubfolders {
      stepIn()
    } else {
      chooseHighlighted()
    }
  }

  /// ⌫ in the empty filter: un-chooses a chosen destination (its token turns back into the query), otherwise steps
  /// out.
  func deleteBackward() {
    cancelNewFolder()
    if destination != nil {
      unchooseRestoringFilter()
    } else {
      stepOut()
    }
  }

  /// Esc: cancels a new folder being named; else clears a chosen destination, the filter and the scope (back to the
  /// archive root); with nothing left to clear, emits ``PickerEvent/steppedBack``.
  func escape() {
    if newFolderDraft != nil {
      cancelNewFolder()
      return
    }
    guard destination != nil || !query.isEmpty || !scope.isEmpty else {
      onEvent(.steppedBack)
      return
    }
    destination = nil
    scope = ""
    query = ""
    update(highlight: .first)
  }

  /// ⇧Tab: cancels a new folder being named; else emits ``PickerEvent/steppedBack`` without clearing anything.
  func stepBack() {
    if newFolderDraft != nil {
      cancelNewFolder()
      return
    }
    onEvent(.steppedBack)
  }

  /// Returns to the archive root with an empty filter, no pending folders and no new-folder row, with `destination`
  /// chosen; call it whenever the panel's selected file changes. A ``PickerDestination/newFolder(_:)`` destination
  /// stays pending.
  func reset(choosing destination: PickerDestination? = nil) {
    newFolderDraft = nil
    stateBeforeDraft = nil
    scope = ""
    query = ""
    pendingFolders = []
    if case .newFolder(let path) = destination { pendingFolders = [path] }
    self.destination = destination
    if let path = destination?.path {
      update(highlight: .anyRow(path, otherwise: .first))
    } else {
      update(highlight: .first)
    }
  }

  /// Entry from the sidebar by typing: cancels a new-folder row, drops a chosen destination without restoring its
  /// filter and appends `text` to the filter.
  func enter(typing text: String) {
    cancelNewFolder()
    let base = filterText
    destination = nil
    query = base + text
    update(highlight: .first)
  }

  // MARK: Stepping

  /// →: steps into the highlighted folder row (indexed or pending), highlighting its "this folder" row. Un-chooses
  /// a chosen destination first.
  func stepIn() {
    cancelNewFolder()
    unchooseRestoringFilter()
    guard case .folder(let folder) = highlightedRow?.kind else { return }
    scope = folder.path
    query = ""
    update(highlight: .currentFolder)
  }

  /// ← or ⌫: steps out to the scope's parent and highlights the folder it came from. At the root, a nested row (a
  /// recent or a search result) steps out to the folder containing it. Un-chooses a chosen destination first.
  func stepOut() {
    cancelNewFolder()
    unchooseRestoringFilter()
    if !scope.isEmpty {
      let origin = scope
      scope = ArchivePath.parent(of: origin)
      query = ""
      update(highlight: .folder(origin, otherwise: .first))
    } else if case .folder(let folder) = highlightedRow?.kind, folder.path.contains("/") {
      scope = ArchivePath.parent(of: folder.path)
      query = ""
      update(highlight: .folder(folder.path, otherwise: .currentFolder))
    }
  }

  /// ⌘↑: to the archive root.
  func jumpToRoot() {
    jump(to: "")
  }

  /// A path-bar click: to `target` (archive-relative, `""` for the root) with an empty filter, highlighting the
  /// folder the picker came from where it is listed. Drops a chosen destination without restoring its filter.
  func jump(to target: String) {
    cancelNewFolder()
    let origin = scope
    destination = nil
    scope = target
    query = ""
    let otherwise: HighlightRequest = target.isEmpty ? .first : .currentFolder
    if let child = Self.childLeading(to: origin, inside: target) {
      update(highlight: .folder(origin, otherwise: .folder(child, otherwise: otherwise)))
    } else {
      update(highlight: otherwise)
    }
  }

  // MARK: New folder

  /// ⇧⌘N or the New Folder button. With the create row highlighted, creates its folder at once (as choosing it).
  /// Otherwise opens the new-folder row in ``newFolderParentTitle``'s folder: the chosen destination if it exists,
  /// else the highlighted folder row if it is not new, else the scope. The view then focuses
  /// ``PickerField/newFolderName``.
  func beginNewFolder() {
    guard newFolderDraft == nil else { return }
    if destination == nil, case .createFolder = highlightedRow?.kind {
      confirmCreateRow()
      return
    }
    let parent = newFolderParent
    stateBeforeDraft = StateBeforeDraft(
      scope: scope, query: query, highlightedRowID: highlightedRowID, destination: destination)
    destination = nil
    scope = parent
    query = ""
    newFolderDraft = NewFolderDraft(parent: parent, name: "", notice: nil)
    update(highlight: .currentFolder)
  }

  /// ⇧⌘N or a click on the highlighted create row: chooses the folder it offers (pending until the move) and emits
  /// ``PickerEvent/chose(_:)``. Does nothing when the create row is not highlighted or its name is invalid.
  func confirmCreateRow() {
    guard let created = highlightedCreateRowDestination else { return }
    choose(created)
    onEvent(.chose(created))
  }

  /// The name typed into the new-folder row, bound to its field; setting it updates the row's position and notice.
  var newFolderName: String {
    get { newFolderDraft?.name ?? "" }
    set {
      guard var draft = newFolderDraft else { return }
      draft.name = newValue
      draft.notice = notice(for: draft)
      newFolderDraft = draft
      update(highlight: .keep)
    }
  }

  /// Tab or Return in the new-folder row: chooses the folder the name gives and emits ``PickerEvent/chose(_:)``.
  /// A new folder becomes pending; a name that exists (ignoring case) chooses the existing folder. An empty name
  /// cancels the row.
  ///
  /// - Returns: `false` when the row stays because the name is invalid (or there is no row); `true` when it ended,
  ///   chosen or cancelled.
  @discardableResult
  func confirmNewFolder() -> Bool {
    switch confirmDraft() {
    case .chose(let chosen):
      onEvent(.chose(chosen))
      return true
    case .cancelled:
      return true
    case .unchanged:
      return false
    }
  }

  /// ⌘Return in the new-folder row: confirms it like ``confirmNewFolder()`` but emits
  /// ``PickerEvent/moveRequested(_:)`` instead.
  @discardableResult
  func confirmNewFolderAndMove() -> Bool {
    switch confirmDraft() {
    case .chose(let chosen):
      onEvent(.moveRequested(chosen))
      return true
    case .cancelled:
      return true
    case .unchanged:
      return false
    }
  }

  /// Esc or ⇧Tab in the new-folder row: removes it and restores the filter, scope, highlight and destination from
  /// before it opened. Does nothing without a row.
  func cancelNewFolder() {
    guard newFolderDraft != nil, let saved = stateBeforeDraft else { return }
    lastDraftEnding = .cancelled
    newFolderDraft = nil
    stateBeforeDraft = nil
    scope = saved.scope
    query = saved.query
    destination = saved.destination
    highlightedRowID = saved.highlightedRowID
    update(highlight: .keep)
  }

  /// How the latest new-folder row ended. The view refocuses the filter only after a cancel: after a choice, the
  /// panel has already moved focus on (to the name field, or the move has started).
  private(set) var lastDraftEnding: NewFolderDraftEnding?

  /// What ``cancelNewFolder()`` restores.
  private struct StateBeforeDraft {
    let scope: String
    let query: String
    let highlightedRowID: PickerRow.ID?
    let destination: PickerDestination?
  }

  /// The parent ``beginNewFolder()`` uses; see there.
  private var newFolderParent: String {
    if case .folder(let path) = destination, index?.contains(path) == true { return path }
    if case .folder(let folder) = highlightedRow?.kind, !folder.isNew { return folder.path }
    return scope
  }

  /// How confirming the new-folder row ended.
  private enum DraftConfirmation {
    /// The row's folder was chosen.
    case chose(PickerDestination)
    /// The name was empty, so the row was cancelled.
    case cancelled
    /// The name is invalid (or there is no row); nothing changed.
    case unchanged
  }

  /// Ends the new-folder row by choosing what its name gives, cancels it for an empty name, keeps it for an invalid
  /// one.
  private func confirmDraft() -> DraftConfirmation {
    guard let draft = newFolderDraft else { return .unchanged }
    let typed = NewFolderPath(typed: draft.name)
    guard
      let chosen = typed.resolved(under: draft.parent, index: index, pendingFolders: pendingFolders)
    else {
      cancelNewFolder()
      return .cancelled
    }
    guard typed.problem == nil else { return .unchanged }
    lastDraftEnding = .chosen
    newFolderDraft = nil
    stateBeforeDraft = nil
    scope = draft.parent
    query = ""
    choose(chosen)
    return .chose(chosen)
  }

  /// The notice the new-folder row shows for `draft`'s name.
  private func notice(for draft: NewFolderDraft) -> NewFolderNotice? {
    let typed = NewFolderPath(typed: draft.name)
    if let problem = typed.problem { return .invalid(problem) }
    guard
      let resolved = typed.resolved(
        under: draft.parent, index: index, pendingFolders: pendingFolders),
      let relativePath = ArchivePath.relative(resolved.path, to: draft.parent)
    else { return nil }
    if case .folder = resolved {
      return .existing(parentTitle: ArchivePath.title(of: draft.parent), existingName: relativePath)
    }
    let components = ArchivePath.segments(of: relativePath)
    return components.count > 1 ? .nested(components) : nil
  }

  // MARK: Folder contents

  /// A click on a file in Folder contents: emits ``PickerEvent/tookFileName(_:)`` with its full name.
  func takeFileName(_ file: FolderFile) {
    onEvent(.tookFileName(file.name))
  }

  // MARK: Refresh

  /// The footer's refresh button: emits ``PickerEvent/refreshRequested``. The picker's state stays as it is; the new
  /// index keeps it where its folders still exist.
  func requestRefresh() {
    onEvent(.refreshRequested)
  }

  /// What ``contents`` should show.
  private enum ContentsTarget: Equatable {
    case none
    case notOnDisk
    case folder(String)
  }

  /// The folder Folder contents follows: the destination if chosen, else the highlighted folder row.
  private var currentContentsTarget: ContentsTarget {
    if newFolderDraft != nil { return .notOnDisk }
    let path: String
    if let destination {
      if case .newFolder = destination { return .notOnDisk }
      path = destination.path
    } else if let highlightedPath = highlightedRow?.folderPath {
      if pendingFolders.contains(highlightedPath) { return .notOnDisk }
      path = highlightedPath
    } else {
      return .none
    }
    return index == nil ? .none : .folder(path)
  }

  /// Updates ``contents`` when the folder it follows changed, cancelling a listing still running.
  private func followContents() {
    let target = currentContentsTarget
    guard target != contentsTarget else { return }
    contentsTarget = target
    contentsTask?.cancel()
    contentsTask = nil
    switch target {
    case .none:
      contents = .none
    case .notOnDisk:
      contents = .notOnDisk
    case .folder(let folder):
      loadContents(of: folder)
    }
  }

  /// Lists `folder` through ``folderFiles`` and shows the result unless a newer listing started meanwhile.
  private func loadContents(of folder: String) {
    guard let index else {
      contents = .none
      return
    }
    contentsLoadNumber += 1
    let loadNumber = contentsLoadNumber
    let listing = folderFiles
    contents = .loading(folder: folder)
    contentsTask = Task { [weak self] in
      let result: Result<[FolderFile], FolderAccessError>
      do throws(FolderAccessError) {
        result = .success(try await listing.files(in: folder, of: index))
      } catch {
        Logger.picker.error(
          "Could not list the files in archive folder \(folder) for Folder contents: \(String(describing: error))"
        )
        result = .failure(error)
      }
      guard let self, loadNumber == self.contentsLoadNumber else { return }
      switch result {
      case .success(let files):
        self.contents = .files(folder: folder, files)
      case .failure(let error):
        self.contents = .failed(folder: folder, message: FolderContents.message(for: error))
      }
    }
  }

  // MARK: Internals

  /// Where the highlight goes when the rows are recomputed.
  private indirect enum HighlightRequest {
    /// The same row id as before, else the first selectable row.
    case keep
    /// The first selectable row.
    case first
    /// The "this folder" row, else the first selectable row.
    case currentFolder
    /// The first folder row for `path` (not "this folder"), else `otherwise`.
    case folder(String, otherwise: HighlightRequest)
    /// The first row standing for `path`, "this folder" included, else `otherwise`.
    case anyRow(String, otherwise: HighlightRequest)
  }

  /// Recomputes the rows and places the highlight.
  private func update(highlight request: HighlightRequest) {
    sections = PickerListing(
      index: index, recents: recents, ranking: ranking, scope: scope, query: query,
      pendingFolders: pendingFolders, draft: newFolderDraft
    ).sections()
    highlightedRowID = resolve(request, among: rows.filter(\.isSelectable))
    followContents()
  }

  private func resolve(_ request: HighlightRequest, among selectable: [PickerRow]) -> PickerRow.ID?
  {
    switch request {
    case .keep:
      if let highlightedRowID, selectable.contains(where: { $0.id == highlightedRowID }) {
        return highlightedRowID
      }
      return selectable.first?.id
    case .first:
      return selectable.first?.id
    case .currentFolder:
      let current = selectable.first { row in
        if case .currentFolder = row.kind { return true }
        return false
      }
      return (current ?? selectable.first)?.id
    case .folder(let path, let otherwise):
      let match = selectable.first { row in
        if case .folder(let folder) = row.kind { return folder.path == path }
        return false
      }
      return match?.id ?? resolve(otherwise, among: selectable)
    case .anyRow(let path, let otherwise):
      let match = selectable.first { $0.folderPath == path }
      return match?.id ?? resolve(otherwise, among: selectable)
    }
  }

  /// The user edited the filter field. Typing cancels a new-folder row and drops a chosen destination without
  /// restoring its filter (the field was empty for both).
  private func changeFilter(to text: String) {
    guard text != filterText else { return }
    cancelNewFolder()
    destination = nil
    query = text
    update(highlight: .first)
  }

  /// Chooses `chosen`, keeping the list and the filter it was chosen from for un-choosing. A new folder becomes
  /// pending, and the highlight moves to its row where it is listed.
  private func choose(_ chosen: PickerDestination) {
    if case .newFolder(let path) = chosen, !pendingFolders.contains(path) {
      pendingFolders.append(path)
    }
    destination = chosen
    if highlightedRow?.folderPath == chosen.path {
      update(highlight: .keep)
    } else {
      update(highlight: .anyRow(chosen.path, otherwise: .keep))
    }
  }

  /// Un-chooses the destination and highlights its row in the list it was chosen from. The filter field shows that
  /// list's filter again.
  private func unchooseRestoringFilter() {
    guard let chosen = destination else { return }
    destination = nil
    update(highlight: .anyRow(chosen.path, otherwise: .keep))
  }

  /// The destination for the folder at `path`: a new folder when it is pending, else an existing one.
  private func destination(for path: String) -> PickerDestination {
    pendingFolders.contains(path) ? .newFolder(path) : .folder(path)
  }

  private func indexDidChange() {
    if let index {
      pendingFolders.removeAll { index.contains($0) }
      if case .newFolder(let path) = destination, index.contains(path) {
        destination = .folder(path)
      }
      while !scope.isEmpty, !index.contains(scope), !pendingFolders.contains(scope) {
        scope = ArchivePath.parent(of: scope)
      }
      if var draft = newFolderDraft {
        draft = NewFolderDraft(parent: scope, name: draft.name, notice: nil)
        draft.notice = notice(for: draft)
        newFolderDraft = draft
      }
    }
    // The folder's files may have changed with the archive (a move adds one), so list them again.
    contentsTarget = nil
    update(highlight: .keep)
  }

  /// The child of `ancestor` on the way to `path`, or `nil` when `path` does not lie strictly inside `ancestor`.
  private static func childLeading(to path: String, inside ancestor: String) -> String? {
    guard let relative = ArchivePath.relative(path, to: ancestor),
      let first = ArchivePath.segments(of: relative).first
    else { return nil }
    return ArchivePath.joining(ancestor, first)
  }
}

/// How a new-folder row ended.
enum NewFolderDraftEnding: Hashable, Sendable {
  /// Its folder was chosen (Tab, Return or ⌘Return).
  case chosen
  /// It was cancelled (Esc, ⇧Tab, an empty name, or another action that closes it).
  case cancelled
}
