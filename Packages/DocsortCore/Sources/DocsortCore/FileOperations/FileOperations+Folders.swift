import Foundation

/// Creating the folders a move needs and removing them again when the move is undone.
extension FileOperations {
  /// The folders from the outermost missing ancestor of `folder` down to `folder`, outermost first; empty when
  /// `folder` exists. Fails when an existing ancestor is not a folder.
  func missingFolders(upTo folder: URL) throws(FileOperationError) -> [URL] {
    var missing: [URL] = []
    var current = folder.standardizedFileURL
    while true {
      if let item = try FileSystemItem.resolvedItem(at: current) {
        guard item.isDirectory else {
          throw .failed(
            operation: "create folder", url: current,
            reason: "an item that is not a folder is in the way")
        }
        return missing.reversed()
      }
      missing.append(current)
      let parent = current.deletingLastPathComponent().standardizedFileURL
      guard parent.path(percentEncoded: false) != current.path(percentEncoded: false) else {
        throw .failed(
          operation: "create folder", url: folder, reason: "no existing folder contains it")
      }
      current = parent
    }
  }

  /// Creates `folders` (outermost first, each inside the previous or an existing folder) and returns those this call
  /// created. A folder that appeared meanwhile is used, not recorded. On failure the created ones are removed again.
  func makeFolders(_ folders: [URL]) throws(FileOperationError) -> [URL] {
    var created: [URL] = []
    for folder in folders {
      let errorCode = folder.withUnsafeFileSystemRepresentation { path in
        guard let path else { return EINVAL }
        return mkdir(path, 0o777) == 0 ? 0 : errno
      }
      switch errorCode {
      case 0:
        created.append(folder)
      case EEXIST where try FileSystemItem.resolvedItem(at: folder)?.isDirectory == true:
        continue
      default:
        let failure = FileOperationError.failed(
          operation: "create folder", url: folder, reason: describePOSIXError(errorCode))
        do {
          try removeEmptyFolders(created)
        } catch {
          throw .failed(
            operation: "create folder", url: folder,
            reason:
              "\(describePOSIXError(errorCode)); removing the folders created before also failed: \(error)"
          )
        }
        throw failure
      }
    }
    return created
  }

  /// Removes those of `folders` (outermost first) that are empty, innermost first. A folder holding only `.DS_Store`
  /// counts as empty. Folders with other content, or already gone, are left alone.
  func removeEmptyFolders(_ folders: [URL]) throws(FileOperationError) {
    for folder in folders.reversed() {
      guard try FileSystemItem.item(at: folder) != nil else { continue }
      let names: [String]
      do {
        names = try FileManager.default.contentsOfDirectory(
          atPath: folder.path(percentEncoded: false))
      } catch {
        throw .failed(operation: "list folder", url: folder, reason: error.localizedDescription)
      }
      if names == [".DS_Store"] {
        try removeFinderMetadata(in: folder)
      } else if !names.isEmpty {
        continue
      }

      let errorCode = folder.withUnsafeFileSystemRepresentation { path in
        guard let path else { return EINVAL }
        return rmdir(path) == 0 ? 0 : errno
      }
      switch errorCode {
      case 0, ENOENT, ENOTEMPTY:
        // ENOTEMPTY: something was put into the folder after it was listed; it stays, as a non-empty folder should.
        continue
      default:
        throw .failed(
          operation: "remove empty folder", url: folder, reason: describePOSIXError(errorCode))
      }
    }
  }

  /// Removes the `.DS_Store` Finder leaves in folders it has shown, so the folder can count as empty.
  private func removeFinderMetadata(in folder: URL) throws(FileOperationError) {
    let metadata = folder.appending(path: ".DS_Store", directoryHint: .notDirectory)
    let errorCode = metadata.withUnsafeFileSystemRepresentation { path in
      guard let path else { return EINVAL }
      return unlink(path) == 0 ? 0 : errno
    }
    guard errorCode == 0 || errorCode == ENOENT else {
      throw .failed(
        operation: "remove .DS_Store", url: metadata, reason: describePOSIXError(errorCode))
    }
  }
}
