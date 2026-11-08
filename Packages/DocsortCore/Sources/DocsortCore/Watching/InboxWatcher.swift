import Foundation

/// Watches inbox folders and delivers each inbox's listing whenever it changes.
///
/// Each inbox is rescanned after changes in its folder (coalesced as ``WatchTiming`` says) and its new state is
/// delivered as an ``InboxUpdate``, with the changes made outside docsort. Scans wait while docsort's own file
/// operations run (``ExpectedChanges``) and leave those operations' changes out.
public struct InboxWatcher: Sendable {
  private let expectedChanges: ExpectedChanges
  private let timing: WatchTiming
  private let eventSource: any FolderEventSource

  /// A watcher that leaves out the changes `expectedChanges` records, timed by `timing`, watching with FSEvents.
  ///
  /// `expectedChanges` must be the instance the filing service runs its operations through.
  public init(expectedChanges: ExpectedChanges, timing: WatchTiming = .standard) {
    self.init(expectedChanges: expectedChanges, timing: timing, eventSource: FSEventsSource())
  }

  /// A watcher that learns of folder changes from `eventSource`.
  init(expectedChanges: ExpectedChanges, timing: WatchTiming, eventSource: any FolderEventSource) {
    self.expectedChanges = expectedChanges
    self.timing = timing
    self.eventSource = eventSource
  }

  /// The updates of `inboxes`, starting with one update per inbox, in the given order, with its current state and
  /// no changes.
  ///
  /// Watching runs while the stream is iterated. When the consumer stops iterating or its task is cancelled, the
  /// folder events, timers and scans stop. The work runs in a task of its own, never on the caller's actor. For an
  /// empty `inboxes`, the stream finishes at once.
  ///
  /// After the initial updates, an update for an inbox is delivered whenever a rescan finds its state changed; a
  /// rescan that finds the same state delivers nothing. Inboxes are rescanned one at a time, those affected by the
  /// same batch of changes in the given order:
  /// - after changes in or above the inbox folder, once its folder has been quiet (``WatchTiming``);
  /// - every ``WatchTiming/retryInterval`` while the inbox is unreachable. When an inbox becomes reachable again, all
  ///   folders are watched anew and every inbox is rescanned once more, since changes in a folder that was missing
  ///   when watching started are not reported, and changes still held for the quiet interval are dropped by the
  ///   restart;
  /// - every ``WatchTiming/retryInterval``, all inboxes, while folder events are unavailable because watching could
  ///   not be started. Each time, starting is tried again first.
  ///
  /// An inbox that cannot be scanned is delivered as ``InboxState/unreachable(_:)``; other inboxes are unaffected, and
  /// nothing ends the stream but the consumer.
  ///
  /// Each inbox is watched and scanned on its own, also when two inboxes share a folder or one lies inside another.
  /// docsort's own changes are then left out only for the first of those inboxes to be rescanned afterwards; the
  /// others may report them as made outside docsort.
  public func updates(for inboxes: [WatchedInbox]) -> AsyncStream<InboxUpdate> {
    let (updates, continuation) = AsyncStream.makeStream(of: InboxUpdate.self)
    guard !inboxes.isEmpty else {
      continuation.finish()
      return updates
    }
    let configuration = WatchConfiguration(
      inboxes: inboxes, expectedChanges: expectedChanges, timing: timing, eventSource: eventSource)
    // Detached, so the watch never runs on the caller's actor (the app calls this from the main actor).
    let driver = Task.detached { await InboxWatch.run(configuration, delivering: continuation) }
    continuation.onTermination = { _ in driver.cancel() }
    return updates
  }
}

/// Everything one watch needs from its ``InboxWatcher``.
private struct WatchConfiguration: Sendable {
  let inboxes: [WatchedInbox]
  let expectedChanges: ExpectedChanges
  let timing: WatchTiming
  let eventSource: any FolderEventSource
}

/// What makes the watch rescan.
private enum WatchTrigger: Sendable {
  /// These inbox folders changed and have been quiet since.
  case changed(Set<URL>)
  /// The retry interval has passed.
  case retryDue
}

/// Whether folder events are coming in.
private enum EventWatch {
  /// Batches of changed folders are forwarded as triggers by this task.
  case running(forwarder: Task<Void, Never>)
  /// Watching could not be started; it is tried again at each retry.
  case unavailable
}

/// How a rescan changed an inbox's state.
private enum StateChange {
  /// The state is the same, or the scan was cancelled.
  case none
  /// The state changed, and the inbox was reachable before (or had no state yet), or is unreachable now.
  case changed
  /// The inbox was unreachable and is listed now.
  case becameReachable
}

/// A scan whose result no file operation of docsort's overlapped.
private struct GatedScan {
  let state: InboxState
  /// docsort's own changes in the inbox since its previous scan.
  let ownChanges: OwnChanges
}

/// The running watch behind one stream of updates. Owned by a single task, which handles one trigger at a time, so
/// its state needs no lock.
private struct InboxWatch {
  private let configuration: WatchConfiguration
  private let folders: Set<URL>
  private let updates: AsyncStream<InboxUpdate>.Continuation
  private let triggers: AsyncStream<WatchTrigger>.Continuation
  private let scanner = InboxScanner()
  /// Each inbox's last delivered state, by its position in ``WatchConfiguration/inboxes``; `nil` before its first
  /// update.
  private var states: [InboxState?]
  private var eventWatch = EventWatch.unavailable
  private var retryTimer: Task<Void, Never>?

  private init(
    _ configuration: WatchConfiguration, updates: AsyncStream<InboxUpdate>.Continuation,
    triggers: AsyncStream<WatchTrigger>.Continuation
  ) {
    self.configuration = configuration
    folders = Set(configuration.inboxes.map(\.folder))
    self.updates = updates
    self.triggers = triggers
    states = Array(repeating: nil, count: configuration.inboxes.count)
  }

  /// Watches until the calling task is cancelled: starts the folder events, delivers the initial updates, then
  /// handles triggers one at a time.
  static func run(
    _ configuration: WatchConfiguration, delivering updates: AsyncStream<InboxUpdate>.Continuation
  ) async {
    let (triggerStream, triggers) = AsyncStream.makeStream(of: WatchTrigger.self)
    var watch = InboxWatch(configuration, updates: updates, triggers: triggers)
    defer { watch.stop() }

    watch.startEventWatch()
    await watch.rescan(Array(configuration.inboxes.indices))
    watch.scheduleRetryIfNeeded()
    // Ends when the task is cancelled; nothing else finishes the triggers.
    for await trigger in triggerStream {
      switch trigger {
      case .changed(let changedFolders):
        await watch.rescan(watch.indices(ofInboxesIn: changedFolders))
      case .retryDue:
        await watch.retry()
      }
      watch.scheduleRetryIfNeeded()
    }
  }

  private func indices(ofInboxesIn changedFolders: Set<URL>) -> [Int] {
    configuration.inboxes.indices.filter {
      changedFolders.contains(configuration.inboxes[$0].folder)
    }
  }

  /// Rescans the inboxes at `indices` in order. When one became reachable again, the folder events were restarted,
  /// which drops the changes the old watch still held for other inboxes, and the inbox's own folder was not watched
  /// before. So every inbox is then rescanned once more, now that the restarted watch covers them all.
  private mutating func rescan(_ indices: [Int]) async {
    var pending = indices
    while !pending.isEmpty {
      var restartedEventWatch = false
      for index in pending {
        guard !Task.isCancelled else { return }
        if await rescanInbox(at: index) == .becameReachable {
          restartedEventWatch = true
        }
      }
      pending = restartedEventWatch ? Array(configuration.inboxes.indices) : []
    }
  }

  /// Rescans the inbox at `index` and delivers its update if its state changed. When it became reachable again, the
  /// folder events are restarted first, so that the update is delivered only once its folder is watched.
  private mutating func rescanInbox(at index: Int) async -> StateChange {
    let inbox = configuration.inboxes[index]
    guard let scan = await scanThroughGate(inbox.folder) else { return .none }
    let previous = states[index]
    guard scan.state != previous else { return .none }
    states[index] = scan.state

    var stateChange = StateChange.changed
    var changes: [InboxChange] = []
    switch (previous, scan.state) {
    case (.listed(let oldListing)?, .listed(let newListing)):
      changes = InboxChange.changes(from: oldListing, to: newListing, excluding: scan.ownChanges)
    case (.unreachable?, .listed):
      stateChange = .becameReachable
      startEventWatch()
    default:
      // A first scan, or a scan to or from unreachable, has no earlier listing to compare with; own changes taken
      // with it are simply dropped.
      break
    }
    updates.yield(InboxUpdate(inboxID: inbox.id, state: scan.state, changes: changes))
    return stateChange
  }

  /// Scans `folder` once no file operation of docsort's runs, and repeats the scan until none overlapped it.
  /// `nil` when the task is cancelled.
  private func scanThroughGate(_ folder: URL) async -> GatedScan? {
    let expectedChanges = configuration.expectedChanges
    while true {
      await expectedChanges.waitUntilIdle()
      guard !Task.isCancelled else { return nil }
      let generation = expectedChanges.generation
      let state: InboxState
      do {
        state = .listed(try scanner.scan(folder))
      } catch {
        state = .unreachable(error)
      }
      if let ownChanges = expectedChanges.takeOwnChanges(
        under: folder, ifNoOperationSince: generation)
      {
        return GatedScan(state: state, ownChanges: ownChanges)
      }
    }
  }

  /// Rescans the unreachable inboxes, or, while folder events are unavailable, tries to start them and rescans
  /// every inbox.
  private mutating func retry() async {
    retryTimer = nil
    switch eventWatch {
    case .unavailable:
      startEventWatch()
      await rescan(Array(configuration.inboxes.indices))
    case .running:
      await rescan(configuration.inboxes.indices.filter { states[$0]?.isUnreachable == true })
    }
  }

  /// Starts a retry timer while an inbox is unreachable or folder events are unavailable, unless one is running,
  /// and stops it when neither is the case any more.
  private mutating func scheduleRetryIfNeeded() {
    let isEventWatchUnavailable =
      switch eventWatch {
      case .unavailable: true
      case .running: false
      }
    guard isEventWatchUnavailable || states.contains(where: { $0?.isUnreachable == true }) else {
      retryTimer?.cancel()
      retryTimer = nil
      return
    }
    guard retryTimer == nil else { return }
    let clock = configuration.timing.clock
    let retryInterval = configuration.timing.retryInterval
    let triggers = triggers
    retryTimer = Task {
      do {
        try await Self.sleep(for: retryInterval, on: clock)
      } catch {
        // Clocks throw only when the sleeping task is cancelled: the retry is no longer needed.
        return
      }
      triggers.yield(.retryDue)
    }
  }

  private static func sleep<C: Clock<Duration>>(for duration: Duration, on clock: C) async throws {
    try await clock.sleep(until: clock.now.advanced(by: duration), tolerance: nil)
  }

  /// Watches every inbox folder anew: stops the current folder events and starts new ones, which deliver batches of
  /// changed folders as triggers.
  private mutating func startEventWatch() {
    stopEventWatch()
    let timing = configuration.timing
    let changedPaths: AsyncStream<String>
    do {
      changedPaths = try configuration.eventSource.changedPaths(under: folders)
    } catch {
      // Not fatal: while folder events are unavailable, every inbox is rescanned at each retry, which also tries to
      // start watching again.
      eventWatch = .unavailable
      return
    }
    let coalescer = ChangeCoalescer(
      quietInterval: timing.quietInterval, maximumDelay: timing.maximumDelay, clock: timing.clock)
    let batches = coalescer.batches(for: folders, changedPaths: changedPaths)
    let triggers = triggers
    eventWatch = .running(
      forwarder: Task {
        for await batch in batches {
          triggers.yield(.changed(batch))
        }
      })
  }

  private mutating func stopEventWatch() {
    if case .running(let forwarder) = eventWatch {
      forwarder.cancel()
    }
    eventWatch = .unavailable
  }

  /// Stops the folder events and the retry timer, and finishes the triggers.
  private mutating func stop() {
    stopEventWatch()
    retryTimer?.cancel()
    retryTimer = nil
    triggers.finish()
  }
}

extension InboxState {
  fileprivate var isUnreachable: Bool {
    switch self {
    case .listed: false
    case .unreachable: true
    }
  }
}
