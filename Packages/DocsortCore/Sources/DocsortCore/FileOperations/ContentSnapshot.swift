import Foundation

/// The state of an item and, for a folder, of everything inside it: identity, size and modification date of each
/// entry. Two snapshots of the same path differ when anything in the tree was replaced, written, added or removed
/// in between, which is how a move across volumes notices that the original changed while it was being copied.
struct ContentSnapshot: Equatable {
  /// One item of the tree, as `lstat` reports it.
  private struct Entry: Equatable {
    let device: dev_t
    let inode: ino_t
    let size: off_t
    let modifiedSeconds: Int
    let modifiedNanoseconds: Int
  }

  /// The entries by path relative to the snapshot's root; the root itself is `""`.
  private let entries: [String: Entry]

  /// A snapshot of the item at `url` (a symbolic link is described, not followed), or `nil` when nothing is there.
  static func of(_ url: URL) throws(FileOperationError) -> ContentSnapshot? {
    var entries: [String: Entry] = [:]
    guard try record(url, as: "", into: &entries) else { return nil }
    return ContentSnapshot(entries: entries)
  }

  /// Adds the entry at `url` (and, for a folder, everything inside it) under `relativePath`. Returns `false` when
  /// nothing is at `url`.
  private static func record(
    _ url: URL, as relativePath: String, into entries: inout [String: Entry]
  ) throws(FileOperationError) -> Bool {
    let operation = "inspect item to copy"
    guard let status = try FileSystemItem.status(at: url, operation: operation, using: lstat) else {
      return false
    }
    entries[relativePath] = Entry(
      device: status.st_dev, inode: status.st_ino, size: status.st_size,
      modifiedSeconds: status.st_mtimespec.tv_sec, modifiedNanoseconds: status.st_mtimespec.tv_nsec)
    guard status.st_mode & S_IFMT == S_IFDIR else { return true }

    let names: [String]
    do {
      names = try FileManager.default.contentsOfDirectory(atPath: url.path(percentEncoded: false))
    } catch {
      throw .failed(operation: operation, url: url, reason: error.localizedDescription)
    }
    for name in names {
      // An entry that vanished between listing and inspecting is simply not part of the snapshot; a comparison with
      // an earlier snapshot still sees it missing.
      _ = try record(
        url.appending(path: name), as: relativePath.isEmpty ? name : "\(relativePath)/\(name)",
        into: &entries)
    }
    return true
  }
}
