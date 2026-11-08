import Foundation
import Synchronization

@testable import DocsortCore

/// A folder event source the test drives by hand.
///
/// Each call of ``changedPaths(under:)`` starts a stream of its own; the test drives the latest one, so a consumer
/// that stops one stream and starts another (a restart) is served by the new stream. ``send(_:)`` hands one path to
/// the consumer and returns only once the consumer asks for the next one, so the consumer has fully handled the path
/// before the test moves on (for example before it advances a clock).
final class FakeFolderEventSource: FolderEventSource {
  private enum Condition {
    /// The consumer of the latest stream is waiting for the next path, or that stream has terminated.
    case consumerReady
    /// The latest stream has terminated: finished by the test or cancelled by the consumer.
    case terminated
  }

  private struct Waiter {
    let condition: Condition
    let continuation: CheckedContinuation<Void, Never>
  }

  /// One stream handed out by ``changedPaths(under:)``.
  private struct Stream {
    var consumer: CheckedContinuation<String?, Never>?
    var isTerminated = false
  }

  private struct State {
    var watchedRoots: [Set<URL>] = []
    /// Every stream handed out, in order; the test drives the last one.
    var streams: [Stream] = []
    var waiters: [Waiter] = []

    func holds(_ condition: Condition) -> Bool {
      guard let latest = streams.last else { return false }
      return switch condition {
      case .consumerReady: latest.consumer != nil || latest.isTerminated
      case .terminated: latest.isTerminated
      }
    }

    /// Terminates the stream at `index`, ending its pending request for a path.
    mutating func terminate(_ index: Int) {
      streams[index].isTerminated = true
      streams[index].consumer?.resume(returning: nil)
      streams[index].consumer = nil
      resumeSatisfiedWaiters()
    }

    mutating func resumeSatisfiedWaiters() {
      var stillWaiting: [Waiter] = []
      for waiter in waiters {
        if holds(waiter.condition) {
          waiter.continuation.resume()
        } else {
          stillWaiting.append(waiter)
        }
      }
      waiters = stillWaiting
    }
  }

  private let state = Mutex(State())

  /// The root sets the consumer asked to watch, in order.
  var watchedRoots: [Set<URL>] { state.withLock { $0.watchedRoots } }

  /// Whether the latest stream has terminated.
  var isTerminated: Bool { state.withLock { $0.streams.last?.isTerminated ?? false } }

  func changedPaths(under roots: Set<URL>) -> AsyncStream<String> {
    let stream = state.withLock { state in
      state.watchedRoots.append(roots)
      state.streams.append(Stream())
      return state.streams.count - 1
    }
    // A stream iterated by an already cancelled task never asks for a path, it only calls `onCancel`.
    return AsyncStream(
      unfolding: { [self] in await nextPath(of: stream) },
      onCancel: { [self] in terminate(stream) })
  }

  /// Hands `path` to the consumer and returns once the consumer has handled it.
  func send(_ path: String) async {
    await wait(for: .consumerReady)
    state.withLock { state in
      guard let latest = state.streams.indices.last, let consumer = state.streams[latest].consumer
      else { return }
      state.streams[latest].consumer = nil
      consumer.resume(returning: path)
    }
    await wait(for: .consumerReady)
  }

  /// Ends the stream once the consumer has handled everything sent before.
  func finish() async {
    await wait(for: .consumerReady)
    state.withLock { state in
      guard let latest = state.streams.indices.last else { return }
      state.terminate(latest)
    }
  }

  /// Suspends until the latest stream has terminated.
  func waitUntilTerminated() async {
    await wait(for: .terminated)
  }

  private func wait(for condition: Condition) async {
    await withCheckedContinuation { continuation in
      state.withLock { state in
        if state.holds(condition) {
          continuation.resume()
        } else {
          state.waiters.append(Waiter(condition: condition, continuation: continuation))
        }
      }
    }
  }

  /// Called by the stream at `index` whenever its consumer asks for the next path.
  private func nextPath(of index: Int) async -> String? {
    await withTaskCancellationHandler {
      await withCheckedContinuation { continuation in
        state.withLock { state in
          if Task.isCancelled || state.streams[index].isTerminated {
            state.streams[index].isTerminated = true
            continuation.resume(returning: nil)
          } else {
            state.streams[index].consumer = continuation
          }
          state.resumeSatisfiedWaiters()
        }
      }
    } onCancel: {
      terminate(index)
    }
  }

  /// Marks the stream at `index` terminated by its consumer and ends its pending request for a path.
  private func terminate(_ index: Int) {
    state.withLock { state in state.terminate(index) }
  }
}
