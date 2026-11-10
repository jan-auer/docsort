import Foundation

/// A folder the user picked in Settings: its bookmark and the path it was last found at.
///
/// The path survives when the bookmark can no longer be resolved, so messages can still name the folder (for example
/// "Folder not found: ~/Drive/Inbox/Scans").
public struct FolderReference: Codable, Hashable, Sendable {
  /// Bookmark data for the folder; security-scoped in the app (see `SecurityScopedBookmarkCoding`).
  public var bookmark: Data
  /// The absolute path the folder was last resolved to, without a trailing slash; updated by `FolderResolver`
  /// whenever resolution yields a different path.
  public var lastKnownPath: String

  /// A reference to the folder with `bookmark`, last found at `lastKnownPath`.
  public init(bookmark: Data, lastKnownPath: String) {
    self.bookmark = bookmark
    self.lastKnownPath = lastKnownPath
  }

  /// A reference to the folder with `bookmark`, last found at `url`.
  init(bookmark: Data, url: URL) {
    self.init(bookmark: bookmark, lastKnownPath: FileLocation.path(of: url))
  }

  /// The last component of `lastKnownPath`, the folder's own name.
  public var folderName: String {
    URL(filePath: lastKnownPath, directoryHint: .isDirectory).lastPathComponent
  }
}
