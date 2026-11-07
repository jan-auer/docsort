import Foundation
import Testing

@testable import DocsortCore

/// A temporary inbox, archive and Trash folder, plus `FileOperations` wired to that Trash.
struct FileOperationsFixture {
  let directory: TemporaryDirectory
  let inbox: URL
  let archive: URL
  let trashFolder: URL
  let operations: FileOperations

  /// `renaming` replaces the exclusive-rename primitive, for example to force the cross-volume path.
  init(renaming: any ExclusiveRenaming = SystemRenaming()) throws {
    directory = try TemporaryDirectory()
    inbox = try directory.createFolder("Inbox")
    archive = try directory.createFolder("Archiv")
    trashFolder = try directory.createFolder("Trash")
    operations = FileOperations(trash: FolderTrash(folder: trashFolder), renaming: renaming)
  }

  /// The names in `folder`, sorted.
  func names(in folder: URL) throws -> [String] {
    try FileManager.default.contentsOfDirectory(atPath: folder.path(percentEncoded: false)).sorted()
  }

  func exists(_ url: URL) -> Bool {
    FileManager.default.fileExists(atPath: url.path(percentEncoded: false))
  }

  func contents(of url: URL) throws -> String {
    String(decoding: try Data(contentsOf: url), as: UTF8.self)
  }

  /// The identity of the item at `url`, which must exist.
  func identity(of url: URL) throws -> FileIdentity {
    try #require(try FileIdentity.ofItem(at: url))
  }

  /// Replaces the item at `url` with a new file holding `contents`, as Finder would when the user swaps files: the new
  /// file exists before the old one is removed, so it cannot reuse the old file's identity.
  func swapFile(at url: URL, contents: String) throws {
    let replacement = try directory.createFile(
      "replacement-\(UUID().uuidString)", contents: contents)
    try FileManager.default.removeItem(at: url)
    try FileManager.default.moveItem(at: replacement, to: url)
  }
}

/// A Trash that moves items into a folder of the test's temporary directory, so tests never touch the user's Trash.
struct FolderTrash: FileTrash {
  let folder: URL

  func moveToTrash(_ url: URL) throws -> URL {
    let trashedURL = folder.appending(path: "\(UUID().uuidString) \(url.lastPathComponent)")
    try FileManager.default.moveItem(at: url, to: trashedURL)
    return trashedURL
  }
}

/// Reports `EXDEV` for every rename between two different folders, as if they were on different volumes; renames
/// inside one folder go to the real primitive.
struct CrossVolumeRenaming: ExclusiveRenaming {
  func renameExclusively(_ source: URL, to destination: URL) -> POSIXErrorCode? {
    let sourceFolder = source.deletingLastPathComponent().standardizedFileURL.path
    let destinationFolder = destination.deletingLastPathComponent().standardizedFileURL.path
    guard sourceFolder == destinationFolder else { return .EXDEV }
    return SystemRenaming().renameExclusively(source, to: destination)
  }
}

/// Which rename primitive a parameterised test runs with.
enum RenamingKind: CustomTestStringConvertible, Sendable {
  case sameVolume
  case crossVolume

  var renaming: any ExclusiveRenaming {
    switch self {
    case .sameVolume: SystemRenaming()
    case .crossVolume: CrossVolumeRenaming()
    }
  }

  var testDescription: String {
    switch self {
    case .sameVolume: "same volume"
    case .crossVolume: "cross volume"
    }
  }
}

/// Fails every rename of one particular item with `EIO`; all other renames go to the real primitive.
struct FailingRenaming: ExclusiveRenaming {
  let failingSource: URL

  func renameExclusively(_ source: URL, to destination: URL) -> POSIXErrorCode? {
    guard source.standardizedFileURL.path != failingSource.standardizedFileURL.path else {
      return .EIO
    }
    return SystemRenaming().renameExclusively(source, to: destination)
  }
}
