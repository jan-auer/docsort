import Foundation

/// What a visible leaf of a folder tree is.
public enum ItemKind: Hashable, Sendable {
  /// A regular file.
  case file
  /// A package: a bundle directory that Finder shows as one document (for example `.rtfd`, `.pages` or Safari's
  /// `.download`). Its contents are never listed separately.
  case package
}

/// A visible folder below the walked root, one the walk descended into. Never a package.
public struct VisibleFolder: Hashable, Sendable {
  /// The folder's location.
  public let url: URL
  /// The path below the walked root, components joined by `/`, without leading or trailing slash (`"A/B"`).
  public let relativePath: String
  /// The folder's own content modification date, when the file system reports one.
  public let modificationDate: Date?
  /// The folder's creation date, when the file system reports one.
  public let creationDate: Date?
}

/// A visible file or package below the walked root.
public struct VisibleItem: Hashable, Sendable {
  /// The item's location.
  public let url: URL
  /// The path below the walked root, components joined by `/`, without leading slash (`"A/B/file.pdf"`).
  public let relativePath: String
  /// Whether the item is a regular file or a package.
  public let kind: ItemKind
  /// The item's content modification date, when the file system reports one.
  public let modificationDate: Date?
  /// The item's creation date, when the file system reports one.
  public let creationDate: Date?
  /// The size of a file's contents in bytes. `nil` for packages, whose size is not known without walking them.
  public let byteCount: Int64?
}

/// A path the walk could not read, with the reason.
public struct ScanProblem: Hashable, Sendable {
  /// The path that could not be read.
  public let url: URL
  /// A human-readable explanation from the file system.
  public let reason: String
}

/// The visible contents of a folder tree, as returned by ``VisibleContentsWalker``.
public struct VisibleContents: Sendable {
  /// The walked root, as passed to the walker.
  public let root: URL
  /// Every visible folder below the root, parents before their children, siblings in Finder name order.
  public let folders: [VisibleFolder]
  /// Every visible file and package below the root, in the same walk order as ``folders``.
  public let items: [VisibleItem]
  /// Subfolders and entries that could not be read, and symbolic links, which are not followed. Everything else is
  /// still listed.
  public let problems: [ScanProblem]

  /// The root-relative paths of ``folders``, in the same order.
  public var folderPaths: [String] { folders.map(\.relativePath) }
}

/// Why a folder tree could not be walked at all.
public enum FolderAccessError: Error, Equatable, Sendable {
  /// Nothing exists at the URL.
  case notFound(URL)
  /// The URL names something that is not a folder.
  case notAFolder(URL)
  /// The folder exists but its contents could not be listed.
  case unreadable(URL, reason: String)
}
