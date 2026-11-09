import Foundation

/// Every folder under the archive root that documents can be filed into, with search and navigation.
///
/// Guarantees:
/// - ``folders`` holds every visible folder below the root (hidden folders and packages are left out, as are the
///   excluded inbox folders and everything inside them), as archive-relative paths without leading or trailing
///   slash, NFC-normalised, parents before children, siblings in Finder name order. The root itself is not listed.
/// - Every method taking a path accepts it in any Unicode normalisation; `""` names the root where noted.
/// - The index is a snapshot: call ``rebuild()`` after creating or renaming folders.
public struct DestinationIndex: Sendable {
  /// The archive root the index was built from.
  public let root: URL
  /// Archive-relative folder paths; see the type's guarantees for their form and order.
  public let folders: [String]
  /// Folders below the root that could not be read; their readable siblings are still indexed.
  public let problems: [ScanProblem]

  private let excludedFolders: [URL]
  /// String hashing is canonical-equivalence aware, so lookups find NFC and NFD spellings alike.
  private let folderSet: Set<String>
  /// The immediate subfolders of each folder, `""` for the root, in ``folders`` order.
  private let subfoldersByParent: [String: [String]]
  private let matcher: DestinationMatcher

  /// Walks `root` and indexes its folders, leaving out each of `excludedFolders` and everything inside it.
  ///
  /// `excludedFolders` are the inbox folders that lie inside the archive; they are compared after resolving symbolic
  /// links, and folders outside the archive are ignored.
  ///
  /// - Throws: ``FolderAccessError`` when `root` is missing, is not a folder, or cannot be listed.
  public static func build(root: URL, excluding excludedFolders: [URL] = [])
    throws(FolderAccessError)
    -> DestinationIndex
  {
    let contents = try VisibleContentsWalker().walk(root)
    let excludedPaths = excludedFolders.compactMap { archiveRelativePath(of: $0, under: root) }

    let folders = contents.folders.map { $0.relativePath.precomposedStringWithCanonicalMapping }
      .filter { !isInside($0, anyOf: excludedPaths) }
    let problems = contents.problems.filter { problem in
      guard let path = archiveRelativePath(of: problem.url, under: root) else { return true }
      return !isInside(path, anyOf: excludedPaths)
    }
    return DestinationIndex(
      root: root, folders: folders, problems: problems, excludedFolders: excludedFolders)
  }

  private init(root: URL, folders: [String], problems: [ScanProblem], excludedFolders: [URL]) {
    self.root = root
    self.folders = folders
    self.problems = problems
    self.excludedFolders = excludedFolders
    folderSet = Set(folders)
    var subfoldersByParent: [String: [String]] = [:]
    for folder in folders {
      subfoldersByParent[Self.parentPath(of: folder), default: []].append(folder)
    }
    self.subfoldersByParent = subfoldersByParent
    matcher = DestinationMatcher(paths: folders)
  }

  /// Walks the archive again with the same root and exclusions; call it after creating a folder.
  ///
  /// - Throws: ``FolderAccessError`` when the root can no longer be listed; the index is then unchanged.
  public mutating func rebuild() throws(FolderAccessError) {
    self = try Self.build(root: root, excluding: excludedFolders)
  }

  /// Whether `path` is an indexed folder, in any Unicode normalisation. The root (`""`) is not one.
  public func contains(_ path: String) -> Bool {
    folderSet.contains(path)
  }

  /// The folders directly below the root, in Finder name order.
  public func topLevelFolders() -> [String] {
    subfolders(of: "")
  }

  /// The indexed folders directly inside `path` (`""` for the root), in Finder name order; empty for a folder
  /// without subfolders or a path that is not indexed.
  public func subfolders(of path: String) -> [String] {
    subfoldersByParent[path] ?? []
  }

  /// The folder containing `path`: `""` for a top-level folder, `nil` for the root itself.
  public func parent(of path: String) -> String? {
    path.isEmpty ? nil : Self.parentPath(of: path.precomposedStringWithCanonicalMapping)
  }

  /// The location of the folder at `path` (`""` for the root).
  public func url(for path: String) -> URL {
    path.isEmpty ? root : root.appending(path: path, directoryHint: .isDirectory)
  }

  /// The indexed folders inside `scope` matching `query`, best first, at most `limit` of them.
  ///
  /// `scope` is the folder the picker is in: an archive-relative path in any Unicode normalisation, `""` (the default)
  /// for the archive root. Only its descendants are searched, not the scope itself, and the query is matched against
  /// each folder's path relative to the scope (``DestinationMatch/pathInScope``), so the scope's own name never
  /// matches. Among matches of comparable quality, folders closer to the scope come first. `ranking` decides whether a
  /// folder named exactly like a query word may outrank a folder one level closer (see ``ScopedRanking``); the default,
  /// ``ScopedRanking/directChildFirst``, keeps closer folders first. A scope that is not indexed has no descendants and
  /// finds nothing.
  ///
  /// An empty or whitespace-only query returns nothing; the UI shows recents and subfolders instead. Recent
  /// destinations that match rank higher; recents never add a folder that does not match. A folder the query's letters
  /// only reach one by one, scattered over its path, does not match (`asdf` finds nothing in
  /// `Ahnenforschung/Stammbaum/Druckfassung`). See
  /// ``DestinationMatch`` for the matched ranges used for highlighting.
  public func search(
    _ query: String, in scope: String = "", ranking: ScopedRanking = .directChildFirst,
    recents: RecentDestinations = .init(), limit: Int = 50
  ) -> [DestinationMatch] {
    matcher.matches(for: query, in: scope, ranking: ranking, recents: recents, limit: limit)
  }

  /// The visible files and packages directly in the folder at `path` (`""` for the root), newest first by
  /// modification date, equal dates in Finder name order.
  ///
  /// Hidden files and the custom-icon file `Icon\r` are left out. A file whose modification date the file system
  /// does not report sorts last.
  ///
  /// - Throws: ``FolderAccessError`` when the folder is missing, is not a folder, or cannot be listed.
  public func files(in path: String) throws(FolderAccessError) -> [FolderFile] {
    // A shallow walk never enters subfolders. An entry whose attributes cannot be read is left out: this listing
    // only shows a folder's contents and has no place to report it.
    let contents = try VisibleContentsWalker().walk(url(for: path), depth: .immediateContents)
    return contents.items
      .filter { $0.url.lastPathComponent != Self.customIconName }
      .map { item in
        FolderFile(
          url: item.url, name: item.url.lastPathComponent,
          modificationDate: item.modificationDate ?? .distantPast)
      }
      .sorted { lhs, rhs in
        if lhs.modificationDate != rhs.modificationDate {
          return lhs.modificationDate > rhs.modificationDate
        }
        return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
      }
  }

  /// The file Finder stores a folder's custom icon in. It usually carries the hidden flag, but not always.
  private static let customIconName = "Icon\r"

  /// The parent of a non-empty archive-relative path, `""` for a top-level one.
  private static func parentPath(of path: String) -> String {
    guard let slash = path.lastIndex(of: "/") else { return "" }
    return String(path[..<slash])
  }

  /// Whether `path` is one of `ancestors` or lies inside one of them; `""` stands for the whole archive.
  private static func isInside(_ path: String, anyOf ancestors: [String]) -> Bool {
    ancestors.contains { ancestor in
      ancestor.isEmpty || path == ancestor || path.hasPrefix(ancestor + "/")
    }
  }

  /// The NFC archive-relative path of `url`, or `nil` when it does not lie inside `root`. Symbolic links are
  /// resolved first, so `/var/…` and `/private/var/…` spellings agree.
  private static func archiveRelativePath(of url: URL, under root: URL) -> String? {
    let components = url.standardizedFileURL.resolvingSymlinksInPath().pathComponents
    let rootComponents = root.standardizedFileURL.resolvingSymlinksInPath().pathComponents
    guard components.starts(with: rootComponents) else { return nil }
    return components.dropFirst(rootComponents.count).joined(separator: "/")
      .precomposedStringWithCanonicalMapping
  }
}

/// A file or package directly inside an archive folder.
public struct FolderFile: Hashable, Sendable {
  /// The item's location.
  public let url: URL
  /// The item's file name, as the file system reports it.
  public let name: String
  /// The item's content modification date; `Date.distantPast` when the file system reports none.
  public let modificationDate: Date

  /// The item at `url`, named `name`, last modified at `modificationDate`.
  public init(url: URL, name: String, modificationDate: Date) {
    self.url = url
    self.name = name
    self.modificationDate = modificationDate
  }
}
