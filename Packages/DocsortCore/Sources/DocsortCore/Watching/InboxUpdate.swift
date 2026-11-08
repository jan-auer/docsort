import Foundation

/// An inbox folder to watch.
public struct WatchedInbox: Hashable, Sendable {
  /// The inbox the updates for this folder are delivered under.
  public let id: InboxFolder.ID
  /// The folder to watch and scan, as resolved for this session (with its security scope already started).
  public let folder: URL

  /// An inbox `id` whose folder is `folder`.
  public init(id: InboxFolder.ID, folder: URL) {
    self.id = id
    self.folder = folder
  }
}

/// What an inbox holds now.
public enum InboxState: Equatable, Sendable {
  /// The inbox could be scanned; this is everything visible in it.
  case listed(InboxListing)
  /// The inbox folder could not be scanned: it is missing (deleted, renamed away, its volume unmounted), is not a
  /// folder, or cannot be listed.
  case unreachable(FolderAccessError)
}

/// One inbox's new state.
///
/// ``state`` is the source of truth: it is what the inbox holds now, whoever changed it. ``changes`` annotate it with
/// what changed outside docsort since the previous update for this inbox; docsort's own moves, trashes and undos are
/// left out, so an update caused only by them has a new listing and no changes.
public struct InboxUpdate: Equatable, Sendable {
  /// The inbox this update is for.
  public let inboxID: InboxFolder.ID
  /// What the inbox holds now. Always differs from the previous update's state for this inbox.
  public let state: InboxState
  /// The changes made outside docsort since the previous update for this inbox, as
  /// ``InboxChange`` describes them. Empty for the first update of an inbox, for an update to or from
  /// ``InboxState/unreachable(_:)``, and when only docsort itself changed the inbox.
  public let changes: [InboxChange]
}

/// Timing of inbox watching.
public struct WatchTiming: Sendable {
  /// How long an inbox must go without changes before it is rescanned, so a burst (a scanner writing several pages,
  /// a folder being copied in) is delivered as one update.
  public let quietInterval: Duration
  /// The longest a change waits for its rescan while changes keep coming, so a long download does not hold back
  /// its inbox.
  public let maximumDelay: Duration
  /// How often unreachable inboxes are rescanned, in addition to rescans caused by events. Also how often every
  /// inbox is rescanned while folder events are unavailable.
  public let retryInterval: Duration
  /// The clock that times all three intervals.
  public let clock: any Clock<Duration>

  /// The timing the app uses: quiet interval 0.5 s, maximum delay 3 s, retry interval 5 s, on the continuous clock.
  public static let standard = WatchTiming()

  /// A timing with the given intervals, timed by `clock`.
  public init(
    quietInterval: Duration = .milliseconds(500), maximumDelay: Duration = .seconds(3),
    retryInterval: Duration = .seconds(5), clock: any Clock<Duration> = ContinuousClock()
  ) {
    self.quietInterval = quietInterval
    self.maximumDelay = maximumDelay
    self.retryInterval = retryInterval
    self.clock = clock
  }
}
