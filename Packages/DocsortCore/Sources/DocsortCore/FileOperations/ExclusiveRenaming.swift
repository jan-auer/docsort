import Foundation

/// The primitive every move is built on: rename an item without ever replacing an existing one.
///
/// It is a seam so tests can make a rename between folders report `EXDEV` and force the cross-volume copy path.
protocol ExclusiveRenaming: Sendable {
  /// Renames `source` to `destination` unless `destination` exists. Returns `nil` on success, otherwise the POSIX
  /// error, such as `EEXIST` when the destination is taken or `EXDEV` when it is on another volume.
  func renameExclusively(_ source: URL, to destination: URL) -> POSIXErrorCode?
}

/// `renamex_np` with `RENAME_EXCL`: the kernel refuses to replace an existing destination, so a file that appears
/// between a check and the rename can still not be overwritten.
struct SystemRenaming: ExclusiveRenaming {
  func renameExclusively(_ source: URL, to destination: URL) -> POSIXErrorCode? {
    let result = source.withUnsafeFileSystemRepresentation { sourcePath in
      destination.withUnsafeFileSystemRepresentation { destinationPath in
        guard let sourcePath, let destinationPath else { return EINVAL }
        return renamex_np(sourcePath, destinationPath, UInt32(RENAME_EXCL)) == 0 ? 0 : errno
      }
    }
    return result == 0 ? nil : POSIXErrorCode(rawValue: result) ?? .EIO
  }
}
