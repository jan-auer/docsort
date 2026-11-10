import Foundation

/// How far below its root a walk goes.
public enum WalkDepth: Hashable, Sendable {
  /// Only the root's own folders, files and packages; subfolders are listed but never entered.
  case immediateContents
  /// Every visible folder, file and package below the root.
  case entireTree
}

/// Walks the visible contents of a folder tree the way Finder shows them.
///
/// Guarantees:
/// - Hidden entries (names starting with `.` and entries with the hidden flag) are skipped and never descended into.
/// - Packages are listed as single items and never descended into.
/// - Symbolic links are never followed, so the walk cannot loop; each one is reported in ``VisibleContents/problems``.
///   Special files (sockets, devices) are skipped.
/// - A subfolder that cannot be listed is reported in ``VisibleContents/problems``; the rest is still walked.
/// - Every item carries its ``FileIdentity``. An item the file system reports no file identifier for is reported in
///   ``VisibleContents/problems`` instead of being listed.
/// - Siblings are visited in Finder name order (`localizedStandardCompare`), so results are deterministic.
public struct VisibleContentsWalker: Sendable {
  /// Creates a walker.
  public init() {}

  /// Walks the visible folders, files and packages below `root`, down to `depth`.
  ///
  /// With ``WalkDepth/immediateContents``, subfolders are listed but never entered, so nothing below them is read
  /// and they cannot cause problems.
  ///
  /// - Throws: ``FolderAccessError`` when `root` is missing, is not a folder, or cannot be listed.
  public func walk(_ root: URL, depth: WalkDepth = .entireTree) throws(FolderAccessError)
    -> VisibleContents
  {
    var rootIsFolder: ObjCBool = false
    guard
      FileManager.default.fileExists(
        atPath: root.path(percentEncoded: false), isDirectory: &rootIsFolder)
    else { throw .notFound(root) }
    guard rootIsFolder.boolValue else { throw .notAFolder(root) }

    var walk = Walk(depth: depth)
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
    .fileSizeKey, .fileIdentifierKey, .volumeUUIDStringKey,
  ]

  let depth: WalkDepth
  var folders: [VisibleFolder] = []
  var items: [VisibleItem] = []
  var problems: [ScanProblem] = []

  /// Records the visible children of `folder` and, for ``WalkDepth/entireTree``, descends into its subfolders.
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
        problems.append(
          ScanProblem(url: child, reason: error.localizedDescription, kind: .unreadable))
        continue
      }

      switch values.fileResourceType {
      case .directory? where values.isPackage != true:
        folders.append(
          VisibleFolder(
            url: child, relativePath: childPath, modificationDate: values.contentModificationDate,
            creationDate: values.creationDate))
        guard depth == .entireTree else { continue }
        do {
          try list(child, relativePath: childPath)
        } catch {
          problems.append(
            ScanProblem(url: child, reason: error.localizedDescription, kind: .unreadable))
        }
      case .directory?:
        appendItem(child, relativePath: childPath, kind: .package, values: values)
      case .regular?:
        appendItem(child, relativePath: childPath, kind: .file, values: values)
      case .symbolicLink?:
        // Links are not followed, so the walk cannot loop or leave the granted folder; report them so a linked
        // folder (for example one pointing into a cloud drive) does not vanish without a word.
        problems.append(
          ScanProblem(
            url: child,
            reason:
              "It is a symbolic link; Docsort does not follow links. Add its target as its own folder.",
            kind: .symbolicLink))
      default:
        // Sockets, devices and unknown types are not documents to file; skipping them is intended.
        continue
      }
    }
  }

  /// Records the file or package at `url`, or a problem when the file system reports no file identifier for it.
  private mutating func appendItem(
    _ url: URL, relativePath: String, kind: ItemKind, values: URLResourceValues
  ) {
    guard let fileID = values.fileIdentifier else {
      problems.append(
        ScanProblem(
          url: url, reason: "The file system reports no file identifier.", kind: .unreadable))
      return
    }
    items.append(
      VisibleItem(
        url: url, identity: FileIdentity(volumeUUID: values.volumeUUIDString, fileID: fileID),
        relativePath: relativePath, kind: kind, modificationDate: values.contentModificationDate,
        creationDate: values.creationDate,
        // A package's size is not known without walking it.
        byteCount: kind == .file ? values.fileSize.map(Int64.init) : nil))
  }
}
