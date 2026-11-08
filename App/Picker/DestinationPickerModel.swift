import DocsortCore
import Foundation
import Observation

/// All state and every intent of the destination picker; see ``PickerContract`` for how the filing panel uses it and
/// `docs/design/ux.md` ("Destination picker") for the behaviour.
///
/// The model never touches the disk itself: it lists folders from ``index`` and reads files through the
/// ``FolderFileListing`` it was created with.
@Observable
final class DestinationPickerModel {
  // MARK: Inputs

  /// The archive's folders, `nil` while it is being built. Setting a new one keeps the highlight and the chosen
  /// destination where their folders still exist, turns pending folders that now exist into ordinary ones, and moves
  /// a scope that no longer exists to its nearest existing ancestor.
  var index: DestinationIndex? {
    didSet { indexDidChange() }
  }

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

  /// The folder under the highlight, for ⌘Return from the picker; `nil` when no folder row is highlighted.
  var highlightedDestination: PickerDestination? {
    guard let path = highlightedRow?.folderPath else { return nil }
    return destination(for: path)
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
    unchooseRestoringFilter()
    let selectable = rows.filter(\.isSelectable)
    guard !selectable.isEmpty else { return }
    let current = selectable.firstIndex { $0.id == highlightedRowID } ?? 0
    let target = min(max(current + offset, 0), selectable.count - 1)
    highlightedRowID = selectable[target].id
  }

  /// Highlights the row with `id` (a click), un-choosing a chosen destination first.
  func highlight(_ id: PickerRow.ID) {
    unchooseRestoringFilter()
    guard rows.contains(where: { $0.id == id && $0.isSelectable }) else { return }
    highlightedRowID = id
  }

  // MARK: Choosing

  /// Chooses the highlighted row (Tab, Return) and emits ``PickerEvent/chose(_:)``. With a destination already
  /// chosen, emits it again so the panel moves on to the name field.
  func chooseHighlighted() {
    if let destination {
      onEvent(.chose(destination))
      return
    }
    guard let chosen = destinationForHighlightedRow() else { return }
    choose(chosen)
    onEvent(.chose(chosen))
  }

  /// ⌘Return: moves the file now. Uses the chosen destination, else chooses the highlighted row first (without
  /// emitting ``PickerEvent/chose(_:)``); emits ``PickerEvent/moveRequested(_:)``. Does nothing when there is
  /// nothing to choose.
  func requestMove() {
    if let destination {
      onEvent(.moveRequested(destination))
      return
    }
    guard let chosen = destinationForHighlightedRow() else { return }
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
    if destination != nil {
      unchooseRestoringFilter()
    } else {
      stepOut()
    }
  }

  /// Esc: clears a chosen destination, the filter and the scope (back to the archive root); with nothing left to
  /// clear, emits ``PickerEvent/steppedBack``.
  func escape() {
    guard destination != nil || !query.isEmpty || !scope.isEmpty else {
      onEvent(.steppedBack)
      return
    }
    destination = nil
    scope = ""
    query = ""
    update(highlight: .first)
  }

  /// ⇧Tab: emits ``PickerEvent/steppedBack`` without clearing anything.
  func stepBack() {
    onEvent(.steppedBack)
  }

  /// Returns to the archive root with an empty filter and no pending folders, with `destination` chosen; call it
  /// whenever the panel's selected file changes. A ``PickerDestination/newFolder(_:)`` destination stays pending.
  func reset(choosing destination: PickerDestination? = nil) {
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

  /// Entry from the sidebar by typing: drops a chosen destination without restoring its filter and appends `text`
  /// to the filter.
  func enter(typing text: String) {
    let base = filterText
    destination = nil
    query = base + text
    update(highlight: .first)
  }

  // MARK: Stepping

  /// →: steps into the highlighted folder row (indexed or pending), highlighting its "this folder" row. Un-chooses
  /// a chosen destination first.
  func stepIn() {
    unchooseRestoringFilter()
    guard case .folder(let folder) = highlightedRow?.kind else { return }
    scope = folder.path
    query = ""
    update(highlight: .currentFolder)
  }

  /// ← or ⌫: steps out to the scope's parent and highlights the folder it came from. At the root, a nested row (a
  /// recent or a search result) steps out to the folder containing it. Un-chooses a chosen destination first.
  func stepOut() {
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
      pendingFolders: pendingFolders
    ).sections()
    highlightedRowID = resolve(request, among: rows.filter(\.isSelectable))
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

  /// The user edited the filter field.
  private func changeFilter(to text: String) {
    if destination != nil {
      // The field is empty while a destination is chosen; only typing into it un-chooses.
      guard !text.isEmpty else { return }
      destination = nil
    } else if text == query {
      return
    }
    query = text
    update(highlight: .first)
  }

  /// Chooses `chosen`, keeping the list and the filter it was chosen from for un-choosing.
  private func choose(_ chosen: PickerDestination) {
    destination = chosen
  }

  /// Un-chooses the destination and highlights its row in the list it was chosen from. The filter field shows that
  /// list's filter again.
  private func unchooseRestoringFilter() {
    guard let chosen = destination else { return }
    destination = nil
    update(highlight: .anyRow(chosen.path, otherwise: .keep))
  }

  /// The destination choosing the highlighted row gives, `nil` when no folder row is highlighted.
  private func destinationForHighlightedRow() -> PickerDestination? {
    highlightedDestination
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
    }
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
