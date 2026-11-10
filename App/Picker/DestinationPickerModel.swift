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
/// (``newFolderName``, ``confirmNewFolder(reporting:)``, ``cancelNewFolder()``); ``escape()``, ``stepBack()`` and
/// ``requestMove()`` act on the row, and any other intent cancels it first.
///
/// Folder contents and New Folder live in `DestinationPickerModel+FolderContents.swift` and
/// `DestinationPickerModel+NewFolder.swift`. Their state is set there too, so the setters below are internal rather
/// than `private(set)`: only the model and those extensions set them.
@Observable
final class DestinationPickerModel {
  // MARK: Inputs

  /// The archive's folders, `nil` while it is being built. Setting a new one keeps the highlight (except right after a
  /// reset, see ``reset(choosing:)``) and the chosen destination where their folders still exist, turns pending
  /// folders that now exist into ordinary ones, and moves a scope that no longer exists to its nearest existing
  /// ancestor.
  var index: DestinationIndex? {
    didSet { indexDidChange() }
  }

  /// Whether the archive index is being rebuilt while ``index`` stays in use; the footer's refresh button shows
  /// progress meanwhile.
  var isRebuildingIndex = false

  /// The recent destinations, most recent first. Setting new ones keeps the highlight on its row, except right after
  /// a reset (see ``reset(choosing:)``).
  var recents: RecentDestinations {
    didSet { inputsDidChange() }
  }

  /// The user's "Rank first" setting for search.
  var ranking: ScopedRanking {
    didSet { inputsDidChange() }
  }

  /// Receives the picker's events; set it once, when the panel creates the model.
  @ObservationIgnored var onEvent: (PickerEvent) -> Void = { _ in }

  // MARK: State

  /// The folder the picker is in, `""` for the archive root.
  var scope = ""

  /// The filter the list is computed from, shown in the filter field. Choosing keeps it, so the list stays as it was
  /// chosen from.
  var query = ""

  /// The sections the list shows, recomputed whenever an input or the state changes.
  private(set) var sections: [PickerSection] = []

  /// The id of the highlighted row; `nil` only when no row is selectable.
  var highlightedRowID: PickerRow.ID?

  /// Where the last reset placed the highlight, while the user has not changed the picker since; `nil` once they
  /// have. New inputs place the highlight there again, so a reset ends on the same row whether the inputs it goes
  /// with (the recents of a move that advanced to the next file) arrive before or after it.
  @ObservationIgnored private var placementSinceReset: HighlightRequest?

  /// Text typed in the sidebar for the filter that the filter field has not received yet, because it has not taken
  /// keyboard focus since (``enter(typing:)``, ``takeTextTypedBeforeFocus()``).
  @ObservationIgnored private var textTypedBeforeFocus = ""

  /// The chosen destination, `nil` until the user chooses one.
  var destination: PickerDestination?

  /// New folders the user named that do not exist on disk yet, in the order they were named.
  private(set) var pendingFolders: [String] = []

  /// The new folder being named in the inline row, `nil` when none is. While it is set, the picker is in its parent
  /// with an empty filter and nothing chosen.
  var newFolderDraft: NewFolderDraft?

  /// The state ``cancelNewFolder()`` returns to.
  @ObservationIgnored var stateBeforeDraft: StateBeforeDraft?

  /// How the latest new-folder row ended. The view refocuses the filter only after a cancel: after a choice, the
  /// panel has already moved focus on (to the name field, or the move has started).
  var lastDraftEnding: NewFolderDraftEnding?

  /// The files Folder contents shows; follows ``destination``, else the highlighted folder row.
  var contents: FolderContents = .none

  /// The file selected in Folder contents (Finder-style: a click selects, ↑ ↓ move it); `nil` when none is. Another
  /// folder clears it.
  var selectedContentsFileURL: URL?

  /// The running listing of ``contents``, if any; tests await it.
  @ObservationIgnored var contentsTask: Task<Void, Never>?

  /// The folder ``contents`` was last loaded for; `nil` forces the next ``followContents()`` to reload.
  @ObservationIgnored var contentsTarget: ContentsTarget?

  /// Counts listings started, so a result that arrives after a newer listing started is dropped.
  @ObservationIgnored var contentsLoadNumber = 0

  /// Lists the files Folder contents shows.
  let folderFiles: any FolderFileListing

  /// A picker at the archive root with nothing chosen.
  init(
    folderFiles: any FolderFileListing, index: DestinationIndex? = nil,
    recents: RecentDestinations = RecentDestinations(), ranking: ScopedRanking = .directChildFirst
  ) {
    self.folderFiles = folderFiles
    self.index = index
    self.recents = recents
    self.ranking = ranking
    place(afterReset: .first)
  }

  // MARK: Derived state

  /// The text of the filter field, bound to it. Choosing a destination leaves it as it is; editing it un-chooses the
  /// destination.
  var filterText: String {
    get { query }
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

  /// The scope's own name, for the placeholder; `nil` at the root.
  var scopeTitle: String? {
    scope.isEmpty ? nil : ArchivePath.title(of: scope)
  }

  /// The folder the file would go to, for the destination line: the chosen destination, else the highlighted folder
  /// (what ⌘Return would choose); `nil` when neither is a folder.
  var destinationPath: DestinationPath? {
    if let destination {
      return DestinationPath(path: destination.path, isChosen: true, isNew: destination.isNew)
    }
    guard let highlighted = highlightedDestination else { return nil }
    return DestinationPath(path: highlighted.path, isChosen: false, isNew: highlighted.isNew)
  }

  /// Whether `row` is the chosen destination's row (it shows a check mark). Choosing moves the highlight onto the
  /// chosen row and moving it un-chooses, so that is the highlighted row while a destination is chosen.
  func isChosen(_ row: PickerRow) -> Bool {
    destination != nil && row.id == highlightedRowID
  }

  /// Where the destination line's folder (the chosen destination, else the highlighted folder) is on disk, for
  /// File › Open Destination in Finder; `nil` when there is none, while it is a pending new folder and while the
  /// archive is being indexed.
  var destinationFolderURL: URL? {
    guard let destinationPath, !destinationPath.isNew else { return nil }
    return locationOnDisk(of: destinationPath.path)
  }

  /// Where the folder `row` stands for is on disk, for the row's Open in Finder and Reveal in Finder; `nil` for a row
  /// that stands for no folder, for a pending new folder and while the archive is being indexed.
  func folderURL(of row: PickerRow) -> URL? {
    guard let path = row.folderPath else { return nil }
    return locationOnDisk(of: path)
  }

  /// The location of the indexed folder at `path`; `nil` for a pending new folder or a path the index lacks.
  private func locationOnDisk(of path: String) -> URL? {
    guard let index, !pendingFolders.contains(path), index.contains(path) else { return nil }
    return index.url(for: path)
  }

  /// Whether the archive is still being indexed (``index`` is `nil`).
  var isIndexing: Bool { index == nil }

  /// The filter field's placeholder: "Indexing archive…", "Search archive", or inside a folder "Search, Gesundheit
  /// first" (a search always covers the whole archive; the folder's matches come first).
  var filterPlaceholder: String {
    if isIndexing { return "Indexing archive…" }
    guard let scopeTitle else { return "Search archive" }
    return "Search, \(scopeTitle) first"
  }

  // MARK: Highlight

  /// Moves the highlight `offset` selectable rows down (negative: up), stopping at the first and last row. A chosen
  /// destination is un-chosen first, which highlights its row.
  func moveHighlight(by offset: Int) {
    cancelNewFolder()
    unchoose()
    let selectable = rows.filter(\.isSelectable)
    guard !selectable.isEmpty else { return }
    let current = selectable.firstIndex { $0.id == highlightedRowID } ?? 0
    let target = (current + offset).clamped(to: 0...selectable.count - 1)
    highlightedRowID = selectable[target].id
    placementSinceReset = nil
    followContents()
  }

  /// Highlights the row with `id` (a click), un-choosing a chosen destination first.
  func highlight(_ id: PickerRow.ID) {
    cancelNewFolder()
    unchoose()
    guard rows.contains(where: { $0.id == id && $0.isSelectable }) else { return }
    highlightedRowID = id
    placementSinceReset = nil
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

  /// ⌘Return: moves the file now. Confirms a new folder being named (see ``confirmNewFolder(reporting:)``), else uses
  /// the chosen destination, else chooses the highlighted row first (without emitting ``PickerEvent/chose(_:)``);
  /// emits ``PickerEvent/moveRequested(_:)``. Does nothing when there is nothing to choose.
  func requestMove() {
    if newFolderDraft != nil {
      confirmNewFolder(reporting: PickerEvent.moveRequested)
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

  /// ⌫ in the empty filter: steps out, un-choosing a chosen destination.
  func deleteBackward() {
    stepOut()
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
  ///
  /// The highlight goes to `destination`'s first row, else the first row (the top of Recent). Until the user changes
  /// the picker, new inputs put it there again rather than keeping its row: after a move, the move's recents may
  /// arrive after the reset, and the folder just used then becomes the top of Recent.
  func reset(choosing destination: PickerDestination? = nil) {
    newFolderDraft = nil
    stateBeforeDraft = nil
    scope = ""
    query = ""
    textTypedBeforeFocus = ""
    pendingFolders = []
    if case .newFolder(let path) = destination { pendingFolders = [path] }
    self.destination = destination
    if let path = destination?.path {
      place(afterReset: .anyRow(path, otherwise: .first))
    } else {
      place(afterReset: .first)
    }
  }

  /// Entry from the sidebar by typing: cancels a new-folder row and keeps `text` for the filter field, which gets it
  /// as typed text once it has keyboard focus (``takeTextTypedBeforeFocus()``). With a destination chosen, it starts
  /// a new search: the chosen destination is dropped and the filter emptied.
  ///
  /// The field receives the text only once it has focus because `NSTextField` selects its whole text when it takes
  /// focus: text put into the filter before would end up selected, and the next key would replace it.
  func enter(typing text: String) {
    cancelNewFolder()
    if destination != nil {
      destination = nil
      query = ""
      update(highlight: .first)
    }
    textTypedBeforeFocus += text
  }

  /// Whether text typed in the sidebar waits for the filter field's focus.
  var hasTextTypedBeforeFocus: Bool {
    !textTypedBeforeFocus.isEmpty
  }

  /// Hands over the text typed in the sidebar (``enter(typing:)``) for the focused filter field to insert as typed,
  /// and forgets it; empty when nothing waits.
  func takeTextTypedBeforeFocus() -> String {
    defer { textTypedBeforeFocus = "" }
    return textTypedBeforeFocus
  }

  /// Forgets text typed in the sidebar that the filter field has not received, because focus went elsewhere.
  func discardTextTypedBeforeFocus() {
    textTypedBeforeFocus = ""
  }

  // MARK: Stepping

  /// →: steps into the highlighted folder row (indexed or pending), highlighting its "this folder" row. Un-chooses
  /// a chosen destination first.
  func stepIn() {
    cancelNewFolder()
    unchoose()
    guard case .folder(let folder) = highlightedRow?.kind else { return }
    scope = folder.path
    query = ""
    update(highlight: .currentFolder)
  }

  /// ← or ⌫: steps out to the scope's parent and highlights the folder it came from. At the root, a nested row (a
  /// recent or a search result) steps out to the folder containing it. Un-chooses a chosen destination first.
  func stepOut() {
    cancelNewFolder()
    unchoose()
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

  // MARK: Refresh

  /// The footer's refresh button: emits ``PickerEvent/refreshRequested``. The picker's state stays as it is; the new
  /// index keeps it where its folders still exist.
  func requestRefresh() {
    onEvent(.refreshRequested)
  }

  // MARK: Internals

  /// Where the highlight goes when the rows are recomputed.
  indirect enum HighlightRequest {
    /// The same row id as before, else the first selectable row.
    case keep
    /// The first selectable row other than the create row, else the create row.
    case first
    /// The "this folder" row, else the first selectable row.
    case currentFolder
    /// The first folder row for `path` (not "this folder"), else `otherwise`.
    case folder(String, otherwise: HighlightRequest)
    /// The first row standing for `path`, "this folder" included, else `otherwise`.
    case anyRow(String, otherwise: HighlightRequest)
  }

  /// Recomputes the rows and places the highlight, for a change by the user (or by new inputs, through
  /// ``inputsDidChange()``): the highlight no longer returns to where the last reset placed it.
  func update(highlight request: HighlightRequest) {
    placementSinceReset = nil
    sections = PickerListing(
      index: index, recents: recents, ranking: ranking, scope: scope, query: query,
      pendingFolders: pendingFolders, draft: newFolderDraft
    ).sections()
    highlightedRowID = resolve(request, among: rows.filter(\.isSelectable))
    followContents()
  }

  /// Recomputes the rows for a reset and places the highlight by `placement`, which new inputs repeat until the user
  /// changes the picker.
  private func place(afterReset placement: HighlightRequest) {
    update(highlight: placement)
    placementSinceReset = placement
  }

  /// Recomputes the rows for new inputs (index, recents, ranking): right after a reset the highlight goes where the
  /// reset placed it, else it stays on its row.
  private func inputsDidChange() {
    if let placementSinceReset {
      place(afterReset: placementSinceReset)
    } else {
      update(highlight: .keep)
    }
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
      // The create row only when nothing else is listed: with matches elsewhere, the first of them (decision
      // `filing-panel-redesign`); ⌘Return and Tab never create a folder anyway.
      let firstFolder = selectable.first { row in
        if case .createFolder = row.kind { return false }
        return true
      }
      return (firstFolder ?? selectable.first)?.id
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

  /// The user edited the filter field. Typing cancels a new-folder row and drops a chosen destination.
  private func changeFilter(to text: String) {
    guard text != query else { return }
    cancelNewFolder()
    destination = nil
    query = text
    update(highlight: .first)
  }

  /// Chooses `chosen`, keeping the list and the filter it was chosen from for un-choosing. A new folder becomes
  /// pending, and the highlight moves to its row where it is listed.
  func choose(_ chosen: PickerDestination) {
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

  /// Un-chooses the destination and highlights its row in the list it was chosen from.
  private func unchoose() {
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
    inputsDidChange()
  }

  /// The child of `ancestor` on the way to `path`, or `nil` when `path` does not lie strictly inside `ancestor`.
  private static func childLeading(to path: String, inside ancestor: String) -> String? {
    guard let relative = ArchivePath.relative(path, to: ancestor),
      let first = ArchivePath.segments(of: relative).first
    else { return nil }
    return ArchivePath.joining(ancestor, first)
  }
}
