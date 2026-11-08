import Foundation
import Synchronization

@testable import DocsortCore

/// A folder event source the test drives by hand. It serves one consumer.
///
/// ``send(_:)`` hands one path to the consumer and returns only once the consumer asks for the next one, so the
/// consumer has fully handled the path before the test moves on (for example before it advances a clock).
final class FakeFolderEventSource: FolderEventSource {
  private enum Condition {
    /// The consumer is waiting for the next path, or the stream has terminated.
    case consumerReady
    /// The stream has terminated: finished by the test or cancelled by the consumer.
    case terminated
  }

  private struct Waiter {
    let condition: Condition
    let continuation: CheckedContinuation<Void, Never>
  }

  private struct State {
    var watchedRoots: [Set<URL>] = []
    var consumer: CheckedContinuation<String?, Never>?
    var isTerminated = false
    var waiters: [Waiter] = []

    func holds(_ condition: Condition) -> Bool {
      switch condition {
      case .consumerReady: consumer != nil || isTerminated
      case .terminated: isTerminated
      }
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

  /// Whether the stream has terminated.
  var isTerminated: Bool { state.withLock { $0.isTerminated } }

  func changedPaths(under roots: Set<URL>) -> AsyncStream<String> {
    state.withLock { $0.watchedRoots.append(roots) }
    // A stream iterated by an already cancelled task never asks for a path, it only calls `onCancel`.
    return AsyncStream(
      unfolding: { [self] in await nextPath() }, onCancel: { [self] in terminate() })
  }

  /// Hands `path` to the consumer and returns once the consumer has handled it.
  func send(_ path: String) async {
    await wait(for: .consumerReady)
    state.withLock { state in
      guard let consumer = state.consumer else { return }
      state.consumer = nil
      consumer.resume(returning: path)
    }
    await wait(for: .consumerReady)
  }

  /// Ends the stream once the consumer has handled everything sent before.
  func finish() async {
    await wait(for: .consumerReady)
    state.withLock { state in
      state.isTerminated = true
      state.consumer?.resume(returning: nil)
      state.consumer = nil
      state.resumeSatisfiedWaiters()
    }
  }

  /// Suspends until the stream has terminated.
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

  /// Called by the stream whenever the consumer asks for the next path.
  private func nextPath() async -> String? {
    await withTaskCancellationHandler {
      await withCheckedContinuation { continuation in
        state.withLock { state in
          if Task.isCancelled || state.isTerminated {
            state.isTerminated = true
            continuation.resume(returning: nil)
          } else {
            state.consumer = continuation
          }
          state.resumeSatisfiedWaiters()
        }
      }
    } onCancel: {
      terminate()
    }
  }

  /// Marks the stream terminated by the consumer and ends a pending request for a path.
  private func terminate() {
    state.withLock { state in
      state.isTerminated = true
      state.consumer?.resume(returning: nil)
      state.consumer = nil
      state.resumeSatisfiedWaiters()
    }
  }
}
