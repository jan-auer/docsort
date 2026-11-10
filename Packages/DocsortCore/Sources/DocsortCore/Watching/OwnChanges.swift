import Foundation

/// The changes docsort itself made below one inbox since its last listing, which the next diff of that inbox leaves
/// out (see ``InboxChange/changes(from:to:excluding:)``).
struct OwnChanges: Hashable, Sendable {
  /// Paths docsort removed an item from (moved out of the inbox, or trashed), as ``path(of:)`` writes them.
  var removals: Set<String>
  /// Paths docsort put an item at (undone or moved back into the inbox), as ``path(of:)`` writes them.
  var arrivals: Set<String>

  /// No changes of docsort's own.
  static let empty = OwnChanges(removals: [], arrivals: [])

  /// The absolute, standardised path by which own changes and listed items are compared: `FileLocation.path(of:)`
  /// of the nearest ancestor that exists (or the item itself), followed by the remaining components.
  ///
  /// Standardising consults the file system: it drops a leading `/private` only when the path exists. A removed
  /// item's path standardised directly could therefore be spelt differently (`/private/var/…`) from the same path
  /// while the item was there, or from its inbox folder (`/var/…`).
  static func path(of url: URL) -> String {
    var existingAncestor = url.standardized
    var missingComponents: [String] = []
    while existingAncestor.path(percentEncoded: false) != "/",
      !FileManager.default.fileExists(atPath: existingAncestor.path(percentEncoded: false))
    {
      missingComponents.insert(existingAncestor.lastPathComponent, at: 0)
      existingAncestor = existingAncestor.deletingLastPathComponent()
    }
    let ancestorPath = FileLocation.path(of: existingAncestor)
    guard !missingComponents.isEmpty else { return ancestorPath }
    let separator = ancestorPath.hasSuffix("/") ? "" : "/"
    return ancestorPath + separator + missingComponents.joined(separator: "/")
  }
}
