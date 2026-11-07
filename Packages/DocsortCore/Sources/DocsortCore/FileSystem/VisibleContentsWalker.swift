import Foundation

/// Walks the visible contents of a folder tree the way Finder shows them.
///
/// Guarantees:
/// - Hidden entries (names starting with `.` and entries with the hidden flag) are skipped and never descended into.
/// - Packages are listed as single items and never descended into.
/// - Symbolic links and special files are skipped; links to folders are never followed, so the walk cannot loop.
/// - A subfolder that cannot be listed is reported in ``VisibleContents/problems``; the rest is still walked.
/// - Siblings are visited in Finder name order (`localizedStandardCompare`), so results are deterministic.
public struct VisibleContentsWalker: Sendable {
  /// Creates a walker.
  public init() {}

  /// Walks every visible folder, file and package below `root`.
  ///
  /// - Throws: ``FolderAccessError`` when `root` is missing, is not a folder, or cannot be listed.
  public func walk(_ root: URL) throws(FolderAccessError) -> VisibleContents {
    var rootIsFolder: ObjCBool = false
    guard
      FileManager.default.fileExists(
        atPath: root.path(percentEncoded: false), isDirectory: &rootIsFolder)
    else { throw .notFound(root) }
    guard rootIsFolder.boolValue else { throw .notAFolder(root) }

    var walk = Walk()
    do {
      try walk.list(root, relativePath: nil)
    } catch {
      throw .unreadable(root, reason: error.localizedDescription)
    }
    return VisibleContents(
      root: root, folders: walk.folders, items: walk.items, problems: walk.problems)
  }
}

/// The state of one walk: everything found so far.
private struct Walk {
  private static let resourceKeys: Set<URLResourceKey> = [
    .fileResourceTypeKey, .isPackageKey, .contentModificationDateKey, .creationDateKey,
    .fileSizeKey,
  ]

  var folders: [VisibleFolder] = []
  var items: [VisibleItem] = []
  var problems: [ScanProblem] = []

  /// Records the visible children of `folder` and descends into its subfolders.
  ///
  /// - Throws: the file system's error when `folder` itself cannot be listed. Failures below it are recorded in
  ///   ``problems`` instead.
  mutating func list(_ folder: URL, relativePath: String?) throws {
    let children = try FileManager.default.contentsOfDirectory(
      at: folder, includingPropertiesForKeys: Array(Self.resourceKeys), options: [.skipsHiddenFiles]
    )
    .sorted {
      $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending
    }

    for child in children {
      let childPath =
        relativePath.map { "\($0)/\(child.lastPathComponent)" } ?? child.lastPathComponent
      let values: URLResourceValues
      do {
        values = try child.resourceValues(forKeys: Self.resourceKeys)
      } catch {
        problems.append(ScanProblem(url: child, reason: error.localizedDescription))
        continue
      }

      switch values.fileResourceType {
      case .directory? where values.isPackage != true:
        folders.append(
          VisibleFolder(
            url: child, relativePath: childPath, modificationDate: values.contentModificationDate,
            creationDate: values.creationDate))
        do {
          try list(child, relativePath: childPath)
        } catch {
          problems.append(ScanProblem(url: child, reason: error.localizedDescription))
        }
      case .directory?:
        items.append(
          VisibleItem(
            url: child, relativePath: childPath, kind: .package,
            modificationDate: values.contentModificationDate, creationDate: values.creationDate,
            byteCount: nil))
      case .regular?:
        items.append(
          VisibleItem(
            url: child, relativePath: childPath, kind: .file,
            modificationDate: values.contentModificationDate,
            creationDate: values.creationDate, byteCount: values.fileSize.map(Int64.init)))
      default:
        // Symbolic links, sockets, devices and unknown types are not documents to file; skipping them is intended.
        continue
      }
    }
  }
}
