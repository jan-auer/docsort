import Foundation

/// A fresh directory under the system's temporary directory, removed when the value is deinitialised.
///
/// Tests build file trees inside it and set modification dates explicitly instead of sleeping between writes.
final class TemporaryDirectory {
  let url: URL

  init() throws {
    url = FileManager.default.temporaryDirectory
      .appending(path: "DocsortCoreTests-\(UUID().uuidString)", directoryHint: .isDirectory)
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
  }

  deinit {
    try? FileManager.default.removeItem(at: url)
  }

  /// Creates a folder (and its missing parents) at `relativePath` and returns its URL.
  @discardableResult
  func createFolder(_ relativePath: String, modified: Date? = nil) throws -> URL {
    let folder = url.appending(path: relativePath, directoryHint: .isDirectory)
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    if let modified {
      try setModificationDate(modified, of: folder)
    }
    return folder
  }

  /// Writes a file at `relativePath`, creating missing parent folders, and returns its URL.
  @discardableResult
  func createFile(_ relativePath: String, contents: String = "content", modified: Date? = nil)
    throws
    -> URL
  {
    let file = url.appending(path: relativePath, directoryHint: .notDirectory)
    try FileManager.default.createDirectory(
      at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
    try Data(contents.utf8).write(to: file)
    if let modified {
      try setModificationDate(modified, of: file)
    }
    return file
  }

  /// Sets the modification date of the item at `itemURL`.
  ///
  /// Writing into a folder updates the folder's own date, so set folder dates after filling them.
  func setModificationDate(_ date: Date, of itemURL: URL) throws {
    try FileManager.default.setAttributes([.modificationDate: date], ofItemAtPath: itemURL.path)
  }
}

/// A fixed reference date plus `seconds`, for deterministic ordering in tests.
func testDate(_ seconds: TimeInterval) -> Date {
  Date(timeIntervalSinceReferenceDate: 800_000_000 + seconds)
}
