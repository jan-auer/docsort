import DocsortCore
import Foundation

/// Which configured inbox a location lies in, for the main window and History alike.
nonisolated enum InboxLocation {
  /// The label of the inbox among `inboxes` (each a label and its folder) that holds `url`: the innermost, should
  /// inboxes nest; `nil` when none does.
  static func label(
    ofInboxHolding url: URL, among inboxes: [(label: String, folder: URL)]
  ) -> String? {
    inboxes
      .filter { DestinationIndex.archiveRelativePath(of: url, under: $0.folder) != nil }
      .max { $0.folder.pathComponents.count < $1.folder.pathComponents.count }?
      .label
  }
}
