import Foundation
import Synchronization

/// Turns a stream of changed paths into batches of the watched roots they affect.
///
/// Per root, changes are held until `quietInterval` has passed without a new change for that root, or until
/// `maximumDelay` has passed since the root's first held change, even while changes keep coming (a long download
/// does not hold back its inbox forever). Roots that become due at the same moment flush in one batch, and a root is
/// in at most one batch at a time: a change after a flush starts a new delay.
struct ChangeCoalescer: Sendable {
  /// How long a root must go without changes before it flushes.
  let quietInterval: Duration
  /// The longest a root's first held change waits before it flushes.
  let maximumDelay: Duration
  /// The clock that times both delays.
  let clock: any Clock<Duration>

  /// The batches of `roots` affected by `changedPaths`, each root as the caller gave it.
  ///
  /// Paths are matched as ``RootMatcher`` describes; paths that affect no root are dropped. When `changedPaths`
  /// ends, every root still held flushes at once in a final batch and the batches finish. When the consumer stops
  /// iterating or its task is cancelled, the timer stops and `changedPaths` is cancelled, which stops its watch.
  func batches(for roots: Set<URL>, changedPaths: AsyncStream<String>) -> AsyncStream<Set<URL>> {
    let (batches, output) = AsyncStream.makeStream(of: Set<URL>.self)
    let matcher = RootMatcher(roots: roots)
    let driver = Task { await coalesce(changedPaths, matcher: matcher, into: output) }
    output.onTermination = { _ in driver.cancel() }
    return batches
  }

  /// Opens the clock existential for the generic coalescing loop.
  private func coalesce(
    _ changedPaths: AsyncStream<String>, matcher: RootMatcher,
    into output: AsyncStream<Set<URL>>.Continuation
  ) async {
    // The compiler opens an existential held in a local constant, but not one read from a stored property.
    let clock: any Clock<Duration> = clock
    await Self.coalesce(
      changedPaths, matcher: matcher, quietInterval: quietInterval, maximumDelay: maximumDelay,
      clock: clock, into: output)
  }

  /// Records each change as it arrives and runs a timer while any root is held. The timer only ever sleeps until
  /// the earliest due time: a new change never makes any root due earlier than that.
  private static func coalesce<C: Clock<Duration>>(
    _ changedPaths: AsyncStream<String>, matcher: RootMatcher, quietInterval: Duration,
    maximumDelay: Duration, clock: C, into output: AsyncStream<Set<URL>>.Continuation
  ) async {
    let heldRoots = HeldRoots<C.Instant>(quietInterval: quietInterval, maximumDelay: maximumDelay)
    await withDiscardingTaskGroup { group in
      for await path in changedPaths {
        let affected = matcher.roots(affectedBy: path)
        guard !affected.isEmpty else { continue }
        if heldRoots.hold(affected, at: clock.now) == .timerNeeded {
          group.addTask { await runTimer(for: heldRoots, clock: clock, into: output) }
        }
      }
      group.cancelAll()
    }
    heldRoots.flushAll(into: output)
    output.finish()
  }

  /// Sleeps until the earliest due time and flushes what is due, until no root is held any more.
  private static func runTimer<C: Clock<Duration>>(
    for heldRoots: HeldRoots<C.Instant>, clock: C, into output: AsyncStream<Set<URL>>.Continuation
  ) async {
    while let deadline = heldRoots.nextDeadline() {
      do {
        try await clock.sleep(until: deadline, tolerance: nil)
      } catch {
        // Clocks throw only when the sleeping task is cancelled, which means the coalescer is shutting down.
        return
      }
      heldRoots.flushDue(at: clock.now, into: output)
    }
  }
}

/// Whether recording a change needs a new timer.
private enum TimerDemand {
  /// No timer is running; the caller starts one.
  case timerNeeded
  /// A running timer will pick up the change.
  case timerRunning
}

/// The roots with held changes and the time of their first and last held change.
private final class HeldRoots<Instant: InstantProtocol>: Sendable
where Instant.Duration == Duration {
  private struct HeldChanges {
    let first: Instant
    var last: Instant
  }

  private struct State {
    var changes: [URL: HeldChanges] = [:]
    var isTimerRunning = false
  }

  private let quietInterval: Duration
  private let maximumDelay: Duration
  private let state = Mutex(State())

  init(quietInterval: Duration, maximumDelay: Duration) {
    self.quietInterval = quietInterval
    self.maximumDelay = maximumDelay
  }

  /// Holds a change to `roots` made at `now`.
  func hold(_ roots: Set<URL>, at now: Instant) -> TimerDemand {
    state.withLock { state in
      for root in roots {
        state.changes[root, default: HeldChanges(first: now, last: now)].last = now
      }
      guard !state.isTimerRunning else { return .timerRunning }
      state.isTimerRunning = true
      return .timerNeeded
    }
  }

  /// The earliest time a held root becomes due, or `nil` when none is held; then the timer counts as stopped.
  func nextDeadline() -> Instant? {
    state.withLock { state in
      guard let deadline = state.changes.values.map(dueTime).min() else {
        state.isTimerRunning = false
        return nil
      }
      return deadline
    }
  }

  /// Flushes every root due at `now` in one batch.
  func flushDue(at now: Instant, into output: AsyncStream<Set<URL>>.Continuation) {
    state.withLock { state in
      let due = Set(state.changes.filter { dueTime($0.value) <= now }.keys)
      guard !due.isEmpty else { return }
      for root in due {
        state.changes[root] = nil
      }
      output.yield(due)
    }
  }

  /// Flushes every held root in one batch.
  func flushAll(into output: AsyncStream<Set<URL>>.Continuation) {
    state.withLock { state in
      guard !state.changes.isEmpty else { return }
      output.yield(Set(state.changes.keys))
      state.changes = [:]
    }
  }

  private func dueTime(_ changes: HeldChanges) -> Instant {
    min(changes.last.advanced(by: quietInterval), changes.first.advanced(by: maximumDelay))
  }
}

/// Decides which watched roots a changed path affects.
///
/// A path affects a root when it is the root, lies inside it, or is an ancestor of it (an unmounted volume, a renamed
/// parent, or `/` for events FSEvents dropped). Each root is compared under its path as given and its real path with
/// symbolic links resolved (FSEvents reports `/private/var/...` for `/var/...`). A root that does not exist resolves
/// through its nearest existing ancestor. Real paths are resolved once, when the matcher is created. Comparison
/// treats Unicode-equivalent spellings as equal but is case-sensitive.
struct RootMatcher: Sendable {
  private struct Root {
    let url: URL
    let paths: Set<String>
  }

  private let roots: [Root]

  /// Creates a matcher for `roots`, resolving their real paths now.
  init(roots: Set<URL>) {
    self.roots = roots.map { root in
      let givenPath = FileLocation.path(of: root)
      return Root(url: root, paths: [givenPath, Self.realPath(of: givenPath)])
    }
  }

  /// The roots that a change at `path` affects.
  func roots(affectedBy path: String) -> Set<URL> {
    let changedPath = FileLocation.withoutTrailingSlashes(path)
    return Set(
      roots.filter { root in root.paths.contains { Self.isRelated(changedPath, $0) } }.map(\.url))
  }

  /// Whether `path` is `rootPath`, inside it, or one of its ancestors.
  private static func isRelated(_ path: String, _ rootPath: String) -> Bool {
    path == rootPath || isAncestor(rootPath, of: path) || isAncestor(path, of: rootPath)
  }

  private static func isAncestor(_ ancestor: String, of path: String) -> Bool {
    ancestor == "/" ? path != "/" : path.hasPrefix(ancestor + "/")
  }

  /// `path` with symbolic links resolved: the real path of its nearest existing ancestor (the path itself if it
  /// exists) followed by the components that do not exist yet. `path` itself when not even `/` resolves.
  private static func realPath(of path: String) -> String {
    var existing = path
    var missingComponents: [String] = []
    while true {
      if let resolved = realpath(existing, nil) {
        defer { free(resolved) }
        // Joined as strings: standardising a URL would turn `/private/var` back into `/var`.
        let base = String(cString: resolved)
        return missingComponents.reversed().reduce(base) { path, component in
          path == "/" ? "/\(component)" : "\(path)/\(component)"
        }
      }
      // `realpath` fails for missing items (and unreadable ones); either way the parent is the next candidate.
      let parent = (existing as NSString).deletingLastPathComponent
      guard parent != existing, !parent.isEmpty else { return path }
      missingComponents.append((existing as NSString).lastPathComponent)
      existing = parent
    }
  }
}
