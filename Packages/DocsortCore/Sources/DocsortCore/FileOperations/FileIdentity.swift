import Foundation

/// Which item on disk a record is about, independent of its path, so an undo can tell the item it moved from another
/// one that took its place.
///
/// It is the volume's UUID (`URLResourceKey.volumeUUIDStringKey`) plus the item's file ID (`st_ino` from `lstat`,
/// the same number as `URLResourceKey.fileIdentifierKey`). Both survive relaunches, restarts and remounts, which a
/// stored record needs:
/// - On APFS (and HFS+) the file ID is the item's persistent object ID: a rename or a move within the volume keeps
///   it, and the file system does not hand out a deleted item's ID to a new item. A copy, and an item that replaces
///   another one at the same path (as Finder, or a sync client writing a new version, does), gets a new ID.
/// - The volume UUID is stored in the volume itself. The alternatives are not persistent: `st_dev` and
///   `volumeIdentifierKey` are assigned when the volume is mounted.
///
/// Volumes without a UUID (some network and FAT volumes) record `nil` for the volume, and their file IDs may not be
/// persistent; the check then compares only the file ID of the item at the recorded path.
public struct FileIdentity: Codable, Hashable, Sendable {
  /// The UUID of the volume the item is on, or `nil` when the volume has none.
  public let volumeUUID: String?
  /// The item's file ID on that volume (its inode number).
  public let fileID: UInt64

  /// An identity from its parts. Read an item's identity from disk with ``FileOperations``, which records it.
  public init(volumeUUID: String?, fileID: UInt64) {
    self.volumeUUID = volumeUUID
    self.fileID = fileID
  }

  /// The identity of the item at `url` itself (a symbolic link is described, not followed), or `nil` when nothing is
  /// there.
  static func ofItem(at url: URL) throws(FileOperationError) -> FileIdentity? {
    guard let item = try FileSystemItem.item(at: url) else { return nil }
    var uncachedURL = url
    // A URL caches resource values; a fresh read is wanted.
    uncachedURL.removeAllCachedResourceValues()
    let volumeUUID: String?
    do {
      volumeUUID = try uncachedURL.resourceValues(forKeys: [.volumeUUIDStringKey]).volumeUUIDString
    } catch {
      throw .failed(operation: "inspect item", url: url, reason: error.localizedDescription)
    }
    return FileIdentity(volumeUUID: volumeUUID, fileID: UInt64(item.inode))
  }

  /// The identity of the item that an operation of this call just put at `url`. Fails when nothing is there.
  static func ofPlacedItem(at url: URL) throws(FileOperationError) -> FileIdentity {
    guard let identity = try ofItem(at: url) else {
      throw .failed(
        operation: "inspect item", url: url, reason: "the item just put there is no longer there")
    }
    return identity
  }
}
