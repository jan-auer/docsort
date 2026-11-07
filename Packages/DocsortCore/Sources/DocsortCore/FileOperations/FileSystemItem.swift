import Foundation

/// The identity and kind of an item on disk, as `lstat`/`stat` report it.
///
/// Two URLs name the same item when their `FileSystemItem`s are equal, which is how a case-only rename is told apart
/// from a real conflict on a case-insensitive volume.
struct FileSystemItem: Equatable {
  let device: dev_t
  let inode: ino_t
  let isDirectory: Bool

  /// The item at `url` itself (a symbolic link is described, not followed), or `nil` when nothing is there.
  static func item(at url: URL) throws(FileOperationError) -> FileSystemItem? {
    try look(at: url, operation: "inspect item", using: lstat)
  }

  /// The item `url` leads to, following symbolic links, or `nil` when nothing is there. Used for folders, which may
  /// be reached through a link.
  static func resolvedItem(at url: URL) throws(FileOperationError) -> FileSystemItem? {
    try look(at: url, operation: "inspect folder", using: stat)
  }

  private static func look(
    at url: URL, operation: String,
    using statFunction: (UnsafePointer<CChar>, UnsafeMutablePointer<stat>) -> Int32
  ) throws(FileOperationError) -> FileSystemItem? {
    var status = stat()
    let errorCode = url.withUnsafeFileSystemRepresentation { path in
      guard let path else { return EINVAL }
      return statFunction(path, &status) == 0 ? 0 : errno
    }
    switch errorCode {
    case 0:
      return FileSystemItem(
        device: status.st_dev, inode: status.st_ino, isDirectory: status.st_mode & S_IFMT == S_IFDIR
      )
    case ENOENT, ENOTDIR:
      return nil
    default:
      throw .failed(operation: operation, url: url, reason: describePOSIXError(errorCode))
    }
  }
}

/// The system's text for a POSIX error number.
func describePOSIXError(_ errorCode: Int32) -> String {
  String(cString: strerror(errorCode))
}
