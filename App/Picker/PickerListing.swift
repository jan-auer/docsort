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
      sections = [searchSection(in: index)]
    } else {
      sections = [
        PickerSection(
          id: "indexing", title: nil, rows: [PickerRow(id: "indexing", kind: .indexing)])
      ]
    }
    return sections.map(insertingDraftRow).filter { !$0.rows.isEmpty }
  }

  /// `section` with the new-folder row at the alphabetical position of the draft name's first component (at the
  /// end while the name is empty), if this is the section listing the scope's children.
  private func insertingDraftRow(into section: PickerSection) -> PickerSection {
    guard let draft, section.id == (scope.isEmpty ? "all" : "browse") else { return section }
    var rows = section.rows
    let draftRow = PickerRow(id: "draft", kind: .newFolderDraft)
    let position =
      NewFolderPath(typed: draft.name).components.first.flatMap { firstComponent in
        rows.firstIndex { row in
          guard case .folder(let folder) = row.kind else { return false }
          return folder.displayPath.localizedStandardCompare(firstComponent) == .orderedDescending
        }
      } ?? rows.endIndex
    rows.insert(draftRow, at: position)
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

  /// The index's matches for the filter inside the scope.
  private func searchSection(in index: DestinationIndex) -> PickerSection {
    let section = "search"
    let matches = index.search(
      query, in: scope, ranking: ranking, recents: recents, limit: Self.searchLimit)
    var rows = matches.map { match in
      PickerRow(
        id: "\(section):\(match.path)",
        kind: .folder(
          PickerFolder(
            path: match.path, displayPath: match.pathInScope, matchedRanges: match.matchedRanges,
            hasSubfolders: !index.subfolders(of: match.path).isEmpty, isNew: false)))
    }
    let newFolder = NewFolderPath(typed: query)
    if rows.isEmpty, !newFolder.components.isEmpty {
      rows.append(
        PickerRow(
          id: "\(section):create",
          kind: .createFolder(name: newFolder.name, parent: scope, problem: newFolder.problem)))
    }
    return PickerSection(id: section, title: nil, rows: rows)
  }

  private func folderRow(section: String, path: String, displayPath: String, isNew: Bool)
    -> PickerRow
  {
    let hasSubfolders = !isNew && !(index?.subfolders(of: path).isEmpty ?? true)
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
