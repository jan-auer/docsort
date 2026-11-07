import Foundation

/// What to do when the name a file is moved to is already taken.
public enum ConflictResolution: Sendable {
  /// Leave everything unchanged and report ``FileOperationError/nameConflict(existing:)``.
  case refuse
  /// Move under the first free name in the sequence `Name 2.pdf`, `Name 3.pdf`, …
  case keepBoth
  /// Send the existing item to the Trash (undoable) and take its name.
  case replace
}

/// What to do when the place an undo puts a file back to is taken. Undo never replaces anything.
public enum UndoConflictResolution: Sendable {
  /// Leave everything unchanged and report ``FileOperationError/originalLocationTaken(_:)``.
  case refuse
  /// Put the file back under the first free name in the sequence `Name 2.pdf`, `Name 3.pdf`, …
  case keepBoth
}

/// An item that was moved to the Trash, with what is needed to put it back.
public struct TrashRecord: Codable, Hashable, Sendable {
  /// Where the item was before it went to the Trash.
  public let originalURL: URL
  /// Where the item is in the Trash.
  public let trashedURL: URL

  /// Records that the item at `originalURL` now lies at `trashedURL`.
  public init(originalURL: URL, trashedURL: URL) {
    self.originalURL = originalURL
    self.trashedURL = trashedURL
  }
}

/// A completed move, with everything needed to undo it.
public struct MoveRecord: Codable, Hashable, Sendable {
  /// Where the file was before the move.
  public let originalURL: URL
  /// Where the file is after the move.
  public let destinationURL: URL
  /// Folders the move created, outermost first. Undo removes those that are empty again.
  public let createdFolders: [URL]
  /// The item that ``ConflictResolution/replace`` sent to the Trash, if any. Undo puts it back.
  public let replaced: TrashRecord?

  /// Records a move from `originalURL` to `destinationURL`.
  public init(originalURL: URL, destinationURL: URL, createdFolders: [URL], replaced: TrashRecord?)
  {
    self.originalURL = originalURL
    self.destinationURL = destinationURL
    self.createdFolders = createdFolders
    self.replaced = replaced
  }
}

/// Why a file operation did not happen. Every case leaves the file system as it was before the call, unless the
/// case's documentation says otherwise.
public enum FileOperationError: Error, Equatable, Sendable {
  /// The target name is taken by `existing` (compared case- and normalisation-insensitively).
  case nameConflict(existing: URL)
  /// The item to move, trash or put back is not there.
  case sourceMissing(URL)
  /// The name (a file name or one folder of a path) cannot be used.
  case invalidName(String, NameProblem)
  /// Undo cannot put the item back because something else now lies at this URL.
  case originalLocationTaken(URL)
  /// The item to put back is no longer in the Trash (for example because the Trash was emptied).
  case notInTrash(URL)
  /// An underlying file-system call failed. `operation` says what was attempted on `url`; `reason` is the
  /// system's explanation plus any detail about what was or was not rolled back.
  case failed(operation: String, url: URL, reason: String)
}
