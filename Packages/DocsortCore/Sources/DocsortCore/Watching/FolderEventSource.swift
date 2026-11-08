import Foundation

/// A source of file-system change notifications for a set of folder trees.
///
/// The element type is a plain absolute path, exactly as the source reports it: no trailing slash is promised, and a
/// path may be spelled canonically (FSEvents reports `/private/var/...` for a root given as `/var/...`) or as the
/// root was given. ``ChangeCoalescer`` maps such paths back to the roots.
protocol FolderEventSource: Sendable {
  /// Starts watching `roots` and everything below them, and returns the paths that change from now on.
  ///
  /// A path is reported when an item at, below or above a root changes (for a root that is renamed, deleted or
  /// unmounted, the root's own path or an ancestor's). Paths may repeat, arrive merged, or stand for a whole subtree
  /// that must be rescanned; consumers rescan rather than apply individual paths.
  ///
  /// Watching runs as long as the stream does: when the consumer stops iterating, its task is cancelled or the
  /// stream is dropped, the watch stops. The stream finishes at once for an empty set of roots.
  ///
  /// - Throws: ``FolderWatchError`` when the watch cannot be set up.
  func changedPaths(under roots: Set<URL>) throws(FolderWatchError) -> AsyncStream<String>
}

/// Why a folder watch could not be started.
enum FolderWatchError: Error, Equatable, Sendable, CustomStringConvertible {
  /// The file-system event service refused to create an event stream for these roots.
  case streamNotCreated(roots: Set<URL>)
  /// The event stream was created but could not be started.
  case streamNotStarted(roots: Set<URL>)

  var description: String {
    switch self {
    case .streamNotCreated(let roots):
      "Could not create a file-system event stream for \(Self.describe(roots))."
    case .streamNotStarted(let roots):
      "Could not start the file-system event stream for \(Self.describe(roots))."
    }
  }

  private static func describe(_ roots: Set<URL>) -> String {
    roots.map { $0.path(percentEncoded: false) }.sorted().joined(separator: ", ")
  }
}
