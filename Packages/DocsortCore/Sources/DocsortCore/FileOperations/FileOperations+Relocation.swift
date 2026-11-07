import Foundation

/// Moving one item to a new path without overwriting anything, on the same volume or across volumes.
extension FileOperations {
  /// Moves `source` to `destination`, which must not exist. Within a volume this is one exclusive rename; across
  /// volumes see ``copyAcrossVolumes(_:to:)``. On failure `source` is where it was and `destination` is free.
  func relocate(_ source: URL, to destination: URL) throws(FileOperationError) {
    switch renaming.renameExclusively(source, to: destination) {
    case nil:
      return
    case .EXDEV:
      try copyAcrossVolumes(source, to: destination)
    case .EEXIST:
      throw .nameConflict(existing: destination)
    case let errorCode?:
      if errorCode == .ENOENT, try FileSystemItem.item(at: source) == nil {
        throw .sourceMissing(source)
      }
      throw .failed(
        operation: "move to \(destination.path(percentEncoded: false))", url: source,
        reason: describePOSIXError(errorCode.rawValue))
    }
  }

  /// Copies `source` to `destination` on another volume, then removes `source`.
  ///
  /// The copy goes to a hidden staging name beside `destination` and is renamed exclusively into place only when it
  /// is complete, so `destination` never holds a partial copy and an item that appeared there meanwhile is never
  /// replaced. If the original cannot be removed afterwards, the copy is removed again and the move fails.
  private func copyAcrossVolumes(_ source: URL, to destination: URL) throws(FileOperationError) {
    guard let sourceItem = try FileSystemItem.item(at: source) else { throw .sourceMissing(source) }
    let operation = "copy to other volume"
    let staging = Self.stagingURL(beside: destination)

    let flags = copyfile_flags_t(
      COPYFILE_ALL | COPYFILE_RECURSIVE | COPYFILE_EXCL | COPYFILE_NOFOLLOW_SRC)
    let copyError = source.withUnsafeFileSystemRepresentation { sourcePath in
      staging.withUnsafeFileSystemRepresentation { stagingPath in
        guard let sourcePath, let stagingPath else { return EINVAL }
        return copyfile(sourcePath, stagingPath, nil, flags) == 0 ? 0 : errno
      }
    }
    if copyError != 0 {
      throw removingStaging(
        staging,
        after: .failed(operation: operation, url: source, reason: describePOSIXError(copyError)))
    }

    switch SystemRenaming().renameExclusively(staging, to: destination) {
    case nil:
      break
    case .EEXIST:
      throw removingStaging(staging, after: .nameConflict(existing: destination))
    case let errorCode?:
      throw removingStaging(
        staging,
        after: .failed(
          operation: operation, url: source, reason: describePOSIXError(errorCode.rawValue)))
    }

    try removeOriginal(source, item: sourceItem, copiedTo: destination)
  }

  /// Removes `source` after it was copied completely to `destination`.
  ///
  /// A file is unlinked in one step; if that fails, the copy is removed so the move did not happen. A folder is
  /// first renamed aside in one step (if that fails, the copy is removed) and then deleted; if deleting it fails
  /// part-way, the complete copy stays at `destination` and the error names both places.
  private func removeOriginal(
    _ source: URL, item: FileSystemItem, copiedTo destination: URL
  ) throws(FileOperationError) {
    let operation = "remove original after copying to other volume"
    let removalTarget: URL
    if item.isDirectory {
      removalTarget = Self.stagingURL(beside: source)
      if let errorCode = SystemRenaming().renameExclusively(source, to: removalTarget) {
        throw removingCopy(
          destination,
          after: .failed(
            operation: operation, url: source, reason: describePOSIXError(errorCode.rawValue)))
      }
      do {
        try FileManager.default.removeItem(at: removalTarget)
      } catch {
        throw .failed(
          operation: operation, url: source,
          reason: """
            \(error.localizedDescription); the complete copy is at \(destination.path(percentEncoded: false)) \
            and what is left of the original is at \(removalTarget.path(percentEncoded: false))
            """)
      }
    } else {
      let errorCode = source.withUnsafeFileSystemRepresentation { path in
        guard let path else { return EINVAL }
        return unlink(path) == 0 ? 0 : errno
      }
      if errorCode != 0 {
        throw removingCopy(
          destination,
          after: .failed(operation: operation, url: source, reason: describePOSIXError(errorCode)))
      }
    }
  }

  /// Removes the complete copy at `copy` because the original could not be removed, and returns the error to throw.
  private func removingCopy(_ copy: URL, after failure: FileOperationError) -> FileOperationError {
    do {
      try FileManager.default.removeItem(at: copy)
      return failure
    } catch {
      return .failed(
        operation: "remove copy after failed move", url: copy,
        reason: """
          \(failure); removing the copy also failed (\(error.localizedDescription)), \
          so it is a duplicate of the unchanged original
          """)
    }
  }

  /// Removes a partial copy at `staging` (if there is one) and returns the error to throw.
  private func removingStaging(_ staging: URL, after failure: FileOperationError)
    -> FileOperationError
  {
    do {
      try FileManager.default.removeItem(at: staging)
      return failure
    } catch CocoaError.fileNoSuchFile {
      return failure
    } catch {
      return .failed(
        operation: "remove partial copy", url: staging,
        reason: """
          \(failure); removing the partial copy also failed (\(error.localizedDescription)); \
          the original is unchanged
          """)
    }
  }

  /// A hidden name in the folder of `url` that no item has.
  private static func stagingURL(beside url: URL) -> URL {
    url.deletingLastPathComponent().appending(
      path: ".docsort-\(UUID().uuidString).partial", directoryHint: .notDirectory)
  }
}
