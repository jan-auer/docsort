import Foundation

@testable import DocsortCore

/// A file URL for an absolute `path`; a trailing slash makes it a directory URL.
func location(_ path: String) -> URL {
  URL(filePath: path, directoryHint: path.hasSuffix("/") ? .isDirectory : .notDirectory)
}

/// A move from `source` to `destination` that created no folders and replaced nothing.
func moveRecord(from source: String, to destination: String) -> MoveRecord {
  MoveRecord(
    originalURL: location(source), destinationURL: location(destination), createdFolders: [],
    replaced: nil)
}

/// A move of the item at `path` into the Trash folder `/Trash`.
func trashRecord(of path: String) -> TrashRecord {
  let original = location(path)
  return TrashRecord(
    originalURL: original, trashedURL: location("/Trash/\(original.lastPathComponent)"))
}
