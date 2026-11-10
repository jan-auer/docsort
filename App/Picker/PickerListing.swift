import DocsortCore
import Foundation

/// The rows the picker lists for one state of its inputs; a pure function of them (see `docs/design/ux.md`,
/// "Destination picker").
struct PickerListing {
  /// The most recent destinations listed at the root.
  static let recentLimit = 20
  /// The most search results listed.
  static let searchLimit = 50

  /// The archive's folders, `nil` while it is being indexed.
  let index: DestinationIndex?
  let recents: RecentDestinations
  let ranking: ScopedRanking
  /// The folder the picker is in, `""` for the archive root.
  let scope: String
  /// The filter the rows are listed for.
  let query: String
  /// New folders the user named that do not exist on disk yet.
  let pendingFolders: [String]
  /// The new folder being named, listed among the scope's children; the scope is its parent then.
  let draft: NewFolderDraft?

  /// The sections to list, without empty ones.
  func sections() -> [PickerSection] {
    let sections: [PickerSection]
    if query.trimmingCharacters(in: .whitespaces).isEmpty {
      sections = scope.isEmpty ? rootSections() : [scopeSection()]
    } else if let index {
      sections = searchSections(in: index)
    } else {
      sections = [
        PickerSection(
          id: "indexing", title: nil, rows: [PickerRow(id: "indexing", kind: .indexing)])
      ]
    }
    return sections.map(insertingDraftRow).filter { !$0.rows.isEmpty }
  }

  /// `section` with the new-folder row directly under its parent, if this is the section listing the scope's
  /// children: after "this folder", or first among the top-level folders at the root.
  ///
  /// The row keeps that place whatever name is typed, so it never jumps while the user types (a lazy list would
  /// also drop the field, and with it the focus, once the row moved out of view). The new folder takes its sorted
  /// place among its siblings once its name is confirmed.
  private func insertingDraftRow(into section: PickerSection) -> PickerSection {
    guard draft != nil, section.id == (scope.isEmpty ? "all" : "browse") else { return section }
    var rows = section.rows
    let position =
      rows.firstIndex { row in
        if case .currentFolder = row.kind { return true }
        return false
      }.map { $0 + 1 } ?? rows.startIndex
    rows.insert(PickerRow(id: "draft", kind: .newFolderDraft), at: position)
    return PickerSection(id: section.id, title: section.title, rows: rows)
  }

  /// Recent (indexed recents, then pending folders), then the top-level folders.
  private func rootSections() -> [PickerSection] {
    let recentPaths = recents.paths.filter { path in
      !path.isEmpty && (index?.contains(path) ?? true)
    }
    .prefix(Self.recentLimit)
    let recentRows =
      recentPaths.map { folderRow(section: "recent", path: $0, displayPath: $0, isNew: false) }
      + pendingFolders.map { folderRow(section: "recent", path: $0, displayPath: $0, isNew: true) }
    let topLevelRows = (index?.topLevelFolders() ?? []).map { path in
      folderRow(section: "all", path: path, displayPath: path, isNew: false)
    }
    return [
      PickerSection(id: "recent", title: "Recent", rows: recentRows),
      PickerSection(id: "all", title: "All folders", rows: topLevelRows),
    ]
  }

  /// "This folder", then the scope's subfolders and the pending folders below it, by display path.
  private func scopeSection() -> PickerSection {
    let section = "browse"
    let subfolderRows = (index?.subfolders(of: scope) ?? []).map { path in
      folderRow(
        section: section, path: path, displayPath: ArchivePath.relative(path, to: scope) ?? path,
        isNew: false)
    }
    let pendingRows = pendingFolders.compactMap { path -> PickerRow? in
      guard let displayPath = ArchivePath.relative(path, to: scope),
        let firstComponent = ArchivePath.segments(of: displayPath).first
      else { return nil }
      // A pending folder inside an existing child is listed inside that child, not here.
      guard index?.contains(ArchivePath.joining(scope, firstComponent)) != true else { return nil }
      return folderRow(section: section, path: path, displayPath: displayPath, isNew: true)
    }
    let childRows = (subfolderRows + pendingRows).sorted { lhs, rhs in
      displayPath(of: lhs).localizedStandardCompare(displayPath(of: rhs)) == .orderedAscending
    }
    let currentRow = PickerRow(id: "\(section):current:\(scope)", kind: .currentFolder(path: scope))
    return PickerSection(id: section, title: nil, rows: [currentRow] + childRows)
  }

  /// The index's matches for the filter. At the root: one untitled section. Inside a folder (soft scope): the whole
  /// archive is searched, the folder's own matches first under "In <folder>" (paths relative to it), the rest under
  /// "Elsewhere" (full paths). When nothing in the folder matches, "In <folder>" holds the create row for a new folder
  /// there (the highlight still goes to the first match elsewhere); when nothing matches anywhere, the create row is
  /// all there is.
  private func searchSections(in index: DestinationIndex) -> [PickerSection] {
    guard !scope.isEmpty else {
      let rows = index.search(
        query, in: scope, ranking: ranking, recents: recents, limit: Self.searchLimit
      ).map { searchRow(section: "search", match: $0, displayPath: $0.pathInScope, index: index) }
      return [PickerSection(id: "search", title: nil, rows: rows.isEmpty ? createRows() : rows)]
    }

    var inScopeRows = index.search(
      query, in: scope, ranking: ranking, recents: recents, limit: Self.searchLimit
    ).map { searchRow(section: "in", match: $0, displayPath: $0.pathInScope, index: index) }
    // The scope itself is not among its descendants; offered as "this folder" when the query names it.
    if index.folder(scope, matches: query, ranking: ranking) {
      inScopeRows.append(PickerRow(id: "in:current:\(scope)", kind: .currentFolder(path: scope)))
    }
    let elsewhereRows = index.search(
      query, outside: scope, ranking: ranking, recents: recents, limit: Self.searchLimit
    ).map { searchRow(section: "elsewhere", match: $0, displayPath: $0.pathInScope, index: index) }

    if inScopeRows.isEmpty, elsewhereRows.isEmpty {
      return [PickerSection(id: "search", title: nil, rows: createRows())]
    }
    // Nothing in the folder: offer the new folder there, above the matches elsewhere.
    let inScope = inScopeRows.isEmpty ? createRows() : inScopeRows
    return [
      PickerSection(id: "in", title: "In \(ArchivePath.title(of: scope))", rows: inScope),
      PickerSection(id: "elsewhere", title: "Elsewhere", rows: elsewhereRows),
    ]
  }

  /// A search result as a folder row of `section`, showing `displayPath`.
  private func searchRow(
    section: String, match: DestinationMatch, displayPath: String, index: DestinationIndex
  ) -> PickerRow {
    PickerRow(
      id: "\(section):\(match.path)",
      kind: .folder(
        PickerFolder(
          path: match.path, displayPath: displayPath, matchedRanges: match.matchedRanges,
          hasSubfolders: !index.subfolders(of: match.path).isEmpty, isNew: false)))
  }

  /// The create row for the filter as a new folder in the scope, if the filter names one.
  private func createRows() -> [PickerRow] {
    let newFolder = NewFolderPath(typed: query)
    guard !newFolder.components.isEmpty else { return [] }
    return [
      PickerRow(
        id: "search:create",
        kind: .createFolder(name: newFolder.name, parent: scope, problem: newFolder.problem))
    ]
  }

  /// A folder row of `section` for the folder at `path`, showing `displayPath`; `isNew` for a pending folder. A pending
  /// folder has no subfolders: the index lacks it (``DestinationPickerModel`` drops pending folders the index lists).
  private func folderRow(section: String, path: String, displayPath: String, isNew: Bool)
    -> PickerRow
  {
    let hasSubfolders = !(index?.subfolders(of: path).isEmpty ?? true)
    return PickerRow(
      id: "\(section):\(path)",
      kind: .folder(
        PickerFolder(
          path: path, displayPath: displayPath, matchedRanges: [], hasSubfolders: hasSubfolders,
          isNew: isNew)))
  }

  private func displayPath(of row: PickerRow) -> String {
    if case .folder(let folder) = row.kind { return folder.displayPath }
    return ""
  }
}
