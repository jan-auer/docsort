import Foundation

@testable import DocsortCore

/// A file URL for an absolute `path`; a trailing slash makes it a directory URL.
func location(_ path: String) -> URL {
  URL(filePath: path, directoryHint: path.hasSuffix("/") ? .isDirectory : .notDirectory)
}

/// A made-up identity for records the history tests build by hand; the history never inspects identities.
let testIdentity = FileIdentity(volumeUUID: "00000000-0000-0000-0000-000000000001", fileID: 1)

/// A move from `source` to `destination` that created no folders and replaced nothing.
func moveRecord(from source: String, to destination: String) -> MoveRecord {
  MoveRecord(
    originalURL: location(source), destinationURL: location(destination), createdFolders: [],
    replaced: nil, movedItem: testIdentity)
}

/// A move of the item at `path` into the Trash folder `/Trash`.
func trashRecord(of path: String) -> TrashRecord {
  let original = location(path)
  return TrashRecord(
    originalURL: original, trashedURL: location("/Trash/\(original.lastPathComponent)"),
    trashedItem: testIdentity)
}
