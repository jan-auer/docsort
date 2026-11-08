import DocsortCore
import Foundation

/// Identifies one inbox file across the app: its sidebar row, the selection, the filing panel and the preview.
///
/// It is backed by the file's identity on disk (`InboxItem.identity`), so it survives a rename or move within its
/// volume: a file renamed in Finder keeps its row and the selection, and a file filed and brought back is the same
/// row. The only place it is built is `init(_:)`.
nonisolated struct InboxItemID: Hashable, Sendable, CustomStringConvertible {
  /// The value the identity is backed by.
  private let identity: FileIdentity

  /// The identity of `item`.
  init(_ item: InboxItem) {
    identity = item.identity
  }

  /// The file ID and volume, for logs.
  var description: String {
    "\(identity.fileID)@\(identity.volumeUUID ?? "no volume UUID")"
  }
}
