import Synchronization

/// A clock whose time moves only when the test advances it.
///
/// `sleep(until:)` suspends until the test advances the clock to or past the deadline, or until the sleeping task is
/// cancelled. Tests call ``waitForSleepers(_:)`` before advancing, so that advancing never races the code under test.
final class ManualClock: Clock {
  /// A point in manual time: the offset from the moment the clock was created.
  struct Instant: InstantProtocol {
    let offset: Duration

    func advanced(by duration: Duration) -> Instant {
      Instant(offset: offset + duration)
    }

    func duration(to other: Instant) -> Duration {
      other.offset - offset
    }

    static func < (lhs: Instant, rhs: Instant) -> Bool {
      lhs.offset < rhs.offset
    }
  }

  private struct Sleeper {
    let deadline: Instant
    let continuation: CheckedContinuation<Void, any Error>
  }

  private struct SleeperCountWaiter {
    let count: Int
    let continuation: CheckedContinuation<Void, Never>
  }

  private struct State {
    var now = Instant(offset: .zero)
    var nextSleeperID = 0
    var sleepers: [Int: Sleeper] = [:]
    var sleeperCountWaiters: [SleeperCountWaiter] = []

    /// Resumes the waiters whose sleeper count is reached.
    mutating func resumeSatisfiedWaiters() {
      let count = sleepers.count
      sleeperCountWaiters.removeAll { waiter in
        guard waiter.count == count else { return false }
        waiter.continuation.resume()
        return true
      }
    }
  }

  private let state = Mutex(State())

  var now: Instant { state.withLock { $0.now } }

  var minimumResolution: Duration { .zero }

  func sleep(until deadline: Instant, tolerance: Duration?) async throws {
    try Task.checkCancellation()
    let id = state.withLock { state in
      state.nextSleeperID += 1
      return state.nextSleeperID
    }
    try await withTaskCancellationHandler {
      try await withCheckedThrowingContinuation {
        (continuation: CheckedContinuation<Void, any Error>) in
        register(Sleeper(deadline: deadline, continuation: continuation), id: id)
      }
    } onCancel: {
      cancelSleeper(id: id)
    }
  }

  private func register(_ sleeper: Sleeper, id: Int) {
    state.withLock { state in
      if Task.isCancelled {
        sleeper.continuation.resume(throwing: CancellationError())
      } else if sleeper.deadline <= state.now {
        sleeper.continuation.resume()
      } else {
        state.sleepers[id] = sleeper
        state.resumeSatisfiedWaiters()
      }
    }
  }

  private func cancelSleeper(id: Int) {
    state.withLock { state in
      guard let sleeper = state.sleepers.removeValue(forKey: id) else { return }
      sleeper.continuation.resume(throwing: CancellationError())
      state.resumeSatisfiedWaiters()
    }
  }

  /// Moves the clock to `offset` after its creation and wakes every sleeper whose deadline is reached.
  func advance(to offset: Duration) {
    state.withLock { state in
      precondition(offset >= state.now.offset, "a manual clock never moves backwards")
      state.now = Instant(offset: offset)
      let due = state.sleepers.filter { $0.value.deadline <= state.now }
      for (id, sleeper) in due {
        state.sleepers[id] = nil
        sleeper.continuation.resume()
      }
      state.resumeSatisfiedWaiters()
    }
  }

  /// Suspends until exactly `count` tasks are sleeping on this clock.
  func waitForSleepers(_ count: Int) async {
    await withCheckedContinuation { continuation in
      state.withLock { state in
        if state.sleepers.count == count {
          continuation.resume()
        } else {
          state.sleeperCountWaiters.append(
            SleeperCountWaiter(count: count, continuation: continuation))
        }
      }
    }
  }
}
