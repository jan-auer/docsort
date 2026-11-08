import DocsortCore
import Foundation

/// Identifies one inbox file across the app: its sidebar row, the selection, the filing panel and the preview.
///
/// It is backed by the file's inbox URL for now. The only place it is built is `init(_:)`, so switching to the core's
/// stable `InboxItem.identity` (with folder watching) is a one-line change there.
nonisolated struct InboxItemID: Hashable, Sendable, CustomStringConvertible {
  /// The value the identity is backed by: the item's location in the inbox when it was listed.
  private let url: URL

  /// The identity of `item`.
  init(_ item: InboxItem) {
    url = item.url
  }

  /// The backing URL's path, for logs.
  var description: String {
    url.path(percentEncoded: false)
  }
}
