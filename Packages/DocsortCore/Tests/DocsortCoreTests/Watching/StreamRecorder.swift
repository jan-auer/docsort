import Synchronization

/// Collects everything an async stream yields, from the moment it is created, so that a test can await a matching
/// element with a timeout. Stops consuming (which terminates the stream) when deinitialised.
final class StreamRecorder<Element: Sendable>: Sendable {
  /// No matching element arrived within the timeout, or the stream ended without one.
  struct NoMatchingElement: Error, CustomStringConvertible {
    let timeout: Duration
    let received: [Element]

    var description: String {
      "no matching element within \(timeout) or before the stream ended; received \(received)"
    }
  }

  private final class Log: Sendable {
    private struct Waiter {
      let skipped: Int
      let predicate: @Sendable (Element) -> Bool
      let continuation: CheckedContinuation<Element?, Never>
    }

    private struct State {
      var elements: [Element] = []
      var isFinished = false
      var nextWaiterID = 0
      var waiters: [Int: Waiter] = [:]
    }

    private let state = Mutex(State())

    var elements: [Element] { state.withLock { $0.elements } }

    func append(_ element: Element) {
      state.withLock { state in
        state.elements.append(element)
        let index = state.elements.count - 1
        for (id, waiter) in state.waiters where index >= waiter.skipped && waiter.predicate(element)
        {
          state.waiters[id] = nil
          waiter.continuation.resume(returning: element)
        }
      }
    }

    func finish() {
      state.withLock { state in
        state.isFinished = true
        for waiter in state.waiters.values {
          waiter.continuation.resume(returning: nil)
        }
        state.waiters = [:]
      }
    }

    /// The first element after the first `skipped` that matches `predicate`, waiting for it if needed; `nil` when
    /// the stream ends without one or the waiting task is cancelled.
    func firstElement(
      afterFirst skipped: Int, where predicate: @escaping @Sendable (Element) -> Bool
    ) async -> Element? {
      let id = state.withLock { state in
        state.nextWaiterID += 1
        return state.nextWaiterID
      }
      return await withTaskCancellationHandler {
        await withCheckedContinuation { continuation in
          state.withLock { state in
            if let match = state.elements.dropFirst(skipped).first(where: predicate) {
              continuation.resume(returning: match)
            } else if state.isFinished || Task.isCancelled {
              continuation.resume(returning: nil)
            } else {
              state.waiters[id] = Waiter(
                skipped: skipped, predicate: predicate, continuation: continuation)
            }
          }
        }
      } onCancel: {
        state.withLock { state in
          state.waiters.removeValue(forKey: id)?.continuation.resume(returning: nil)
        }
      }
    }
  }

  private let log: Log
  private let consumer: Task<Void, Never>

  init(_ stream: AsyncStream<Element>) {
    let log = Log()
    self.log = log
    consumer = Task {
      for await element in stream {
        log.append(element)
      }
      log.finish()
    }
  }

  deinit {
    consumer.cancel()
  }

  /// Everything received so far, in order.
  var elements: [Element] { log.elements }

  /// The first element matching `predicate`, waiting up to `timeout` for it. With `skipped`, only elements after
  /// the first `skipped` ones count (for example after everything received so far).
  ///
  /// - Throws: ``NoMatchingElement`` when none arrives in time or the stream ends without one.
  @discardableResult
  func firstElement(
    afterFirst skipped: Int = 0, within timeout: Duration = .seconds(10),
    where predicate: @escaping @Sendable (Element) -> Bool
  ) async throws -> Element {
    let log = log
    let match = await withTaskGroup(of: Element?.self) { group in
      group.addTask { await log.firstElement(afterFirst: skipped, where: predicate) }
      group.addTask {
        // Cancellation only means the match arrived first; either way this task ends without an element.
        try? await Task.sleep(for: timeout)
        return nil
      }
      let first = await group.next() ?? nil
      group.cancelAll()
      return first
    }
    guard let match else {
      throw NoMatchingElement(timeout: timeout, received: log.elements)
    }
    return match
  }
}
