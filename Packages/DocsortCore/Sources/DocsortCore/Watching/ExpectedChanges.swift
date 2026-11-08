import Foundation
import Synchronization

/// A change docsort itself makes to an inbox, which inbox watching must not report as made outside the app.
///
/// For the filing service only; the UI never names these.
public enum ExpectedChange: Hashable, Sendable {
  /// docsort removed the item at this path from an inbox (moved it out, or trashed it).
  case removal(of: URL)
  /// docsort put an item at this path in an inbox (undo, move back).
  case arrival(at: URL)
}

/// The registry of docsort's own changes to inboxes, so that inbox watching leaves out the filing service's moves,
/// trashes and undos and reports only changes made outside the app.
///
/// For the filing service only: it runs every file operation that touches an inbox through ``perform(_:expecting:)``.
/// The app creates one instance and hands it to both the filing service and the inbox watcher; the UI never calls it.
///
/// The watcher holds its diffs while an operation runs and discards any scan that overlapped one, so matching own
/// changes by path is race-free. Each recorded change is taken, and so forgotten, by the first diff of its inbox.
/// Operations may run concurrently from several threads.
public final class ExpectedChanges: Sendable {
  private struct State {
    var runningOperationCount = 0
    var generation: UInt64 = 0
    var recorded = OwnChanges.empty
    var nextWaiterID: UInt64 = 0
    var idleWaiters: [UInt64: CheckedContinuation<Void, Never>] = [:]
  }

  private let state = Mutex(State())

  /// Creates an empty registry.
  public init() {}

  /// Runs `operation` as docsort's own change. While it runs, watchers hold their diffs. When it succeeds, the changes
  /// `expected(result)` names are recorded before any watcher can diff again; when it throws, nothing is recorded and
  /// the error is rethrown unchanged.
  public func perform<T, E: Error>(
    _ operation: () throws(E) -> T, expecting expected: (T) -> [ExpectedChange]
  ) throws(E) -> T {
    state.withLock { state in
      state.runningOperationCount += 1
      state.generation += 1
    }
    let result: T
    do throws(E) {
      result = try operation()
    } catch {
      finishOperation(recording: .empty)
      throw error
    }
    finishOperation(recording: Self.ownChanges(expected(result)))
    return result
  }

  /// A counter that changes whenever an operation starts or finishes.
  ///
  /// A watcher reads it before scanning and passes it to ``takeOwnChanges(under:ifNoOperationSince:)`` afterwards,
  /// which fails when an operation ran during the scan. Because it also changes when an operation finishes, a value
  /// read while an operation was running never passes that check.
  var generation: UInt64 {
    state.withLock { $0.generation }
  }

  /// Returns when no operation is running: at once when none is, otherwise as soon as the running ones have finished.
  ///
  /// Also returns, early, when the waiting task is cancelled; a caller that goes on to scan is still protected, since
  /// ``takeOwnChanges(under:ifNoOperationSince:)`` fails while an operation runs.
  func waitUntilIdle() async {
    let waiterID: UInt64? = state.withLock { state in
      guard state.runningOperationCount > 0 else { return nil }
      state.nextWaiterID += 1
      return state.nextWaiterID
    }
    guard let waiterID else { return }

    await withTaskCancellationHandler {
      await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
        let isAlreadyResumable = state.withLock { state in
          guard state.runningOperationCount > 0, !Task.isCancelled else { return true }
          state.idleWaiters[waiterID] = continuation
          return false
        }
        if isAlreadyResumable { continuation.resume() }
      }
    } onCancel: {
      state.withLock { $0.idleWaiters.removeValue(forKey: waiterID) }?.resume()
    }
  }

  /// Removes and returns the recorded changes at `root` or below it, or returns `nil` and keeps them when an operation
  /// is running or one started or finished since `generation` was read: a scan made since then may have overlapped
  /// the operation and must be redone.
  func takeOwnChanges(under root: URL, ifNoOperationSince generation: UInt64) -> OwnChanges? {
    let rootPath = OwnChanges.path(of: root)
    let descendantPrefix = rootPath.hasSuffix("/") ? rootPath : rootPath + "/"
    func isUnderRoot(_ path: String) -> Bool {
      path == rootPath || path.hasPrefix(descendantPrefix)
    }

    return state.withLock { state in
      guard state.runningOperationCount == 0, state.generation == generation else { return nil }
      let taken = OwnChanges(
        removals: state.recorded.removals.filter(isUnderRoot),
        arrivals: state.recorded.arrivals.filter(isUnderRoot))
      state.recorded.removals.subtract(taken.removals)
      state.recorded.arrivals.subtract(taken.arrivals)
      return taken
    }
  }

  /// Records `changes` and ends one running operation, resuming the idle waiters when it was the last.
  private func finishOperation(recording changes: OwnChanges) {
    let resumableWaiters = state.withLock { state in
      state.recorded.removals.formUnion(changes.removals)
      state.recorded.arrivals.formUnion(changes.arrivals)
      state.runningOperationCount -= 1
      state.generation += 1
      guard state.runningOperationCount == 0 else { return [CheckedContinuation<Void, Never>]() }
      defer { state.idleWaiters = [:] }
      return Array(state.idleWaiters.values)
    }
    for waiter in resumableWaiters {
      waiter.resume()
    }
  }

  /// `changes` with their paths spelt as diffs compare them. Computed outside the lock, since it reads the file system.
  private static func ownChanges(_ changes: [ExpectedChange]) -> OwnChanges {
    var ownChanges = OwnChanges.empty
    for change in changes {
      switch change {
      case .removal(let url): ownChanges.removals.insert(OwnChanges.path(of: url))
      case .arrival(let url): ownChanges.arrivals.insert(OwnChanges.path(of: url))
      }
    }
    return ownChanges
  }
}
