import Foundation
import Synchronization
import Testing

@testable import DocsortCore

@Suite("ExpectedChanges", .timeLimit(.minutes(1)))
struct ExpectedChangesTests {
  let registry = ExpectedChanges()
  let directory: TemporaryDirectory
  let inbox: URL

  init() throws {
    directory = try TemporaryDirectory()
    inbox = try directory.createFolder("Eingang")
  }

  @Test("records the changes an operation that succeeds names, and returns its result")
  func recordsOnSuccess() {
    let filed = inbox.appending(path: "scan-1.pdf")
    let restored = inbox.appending(path: "Ordner/Invoice.pdf")

    let result = registry.perform(
      { 42 },
      expecting: { result in
        #expect(result == 42)
        return [.removal(of: filed), .arrival(at: restored)]
      })

    #expect(result == 42)
    #expect(
      registry.takeOwnChanges(under: inbox, ifNoOperationSince: registry.generation)
        == OwnChanges(
          removals: [OwnChanges.path(of: filed)], arrivals: [OwnChanges.path(of: restored)]))
  }

  @Test("records nothing when the operation throws, and rethrows its typed error unchanged")
  func recordsNothingOnFailure() {
    let failure = OperationFailure(reason: "disk full")

    do throws(OperationFailure) {
      _ = try registry.perform(
        { () throws(OperationFailure) -> Int in throw failure },
        expecting: { _ in
          Issue.record("expected changes asked for after a failure")
          return [.removal(of: inbox.appending(path: "scan-1.pdf"))]
        })
      Issue.record("perform did not throw")
    } catch {
      #expect(error == failure)
    }

    #expect(
      registry.takeOwnChanges(under: inbox, ifNoOperationSince: registry.generation) == .empty)
  }

  @Test("refuses to hand out changes while an operation is running")
  func refusesWhileRunning() async throws {
    let generationBefore = registry.generation
    let filed = inbox.appending(path: "scan-1.pdf")
    let operation = await HeldOperation.start(in: registry, expecting: [.removal(of: filed)])

    #expect(registry.takeOwnChanges(under: inbox, ifNoOperationSince: generationBefore) == nil)
    #expect(registry.takeOwnChanges(under: inbox, ifNoOperationSince: registry.generation) == nil)

    operation.release()
    try await completion(of: Task { [registry] in await registry.waitUntilIdle() })
    #expect(
      registry.takeOwnChanges(under: inbox, ifNoOperationSince: registry.generation)
        == OwnChanges(removals: [OwnChanges.path(of: filed)], arrivals: []))
  }

  @Test(
    "refuses to hand out changes when an operation started since the generation, and keeps them")
  func refusesAfterOperationSinceGeneration() {
    let generationBeforeScan = registry.generation
    let filed = inbox.appending(path: "scan-1.pdf")
    registry.perform({}, expecting: { _ in [.removal(of: filed)] })

    #expect(registry.takeOwnChanges(under: inbox, ifNoOperationSince: generationBeforeScan) == nil)
    #expect(
      registry.takeOwnChanges(under: inbox, ifNoOperationSince: registry.generation)
        == OwnChanges(removals: [OwnChanges.path(of: filed)], arrivals: []))
  }

  @Test("refuses a generation read while an operation was running, even after it finished")
  func refusesGenerationReadDuringOperation() async throws {
    let operation = await HeldOperation.start(
      in: registry, expecting: [.removal(of: inbox.appending(path: "scan-1.pdf"))])
    let generationDuringOperation = registry.generation

    operation.release()
    try await completion(of: Task { [registry] in await registry.waitUntilIdle() })

    #expect(
      registry.takeOwnChanges(under: inbox, ifNoOperationSince: generationDuringOperation) == nil)
  }

  @Test("hands out only the changes under the root, and each only once")
  func takesChangesUnderRootOnce() throws {
    let otherInbox = try directory.createFolder("Eingang 2")
    let inInbox = inbox.appending(path: "scan-1.pdf")
    let deepInInbox = inbox.appending(path: "A/B/scan-2.pdf")
    let inOtherInbox = otherInbox.appending(path: "scan-1.pdf")
    registry.perform(
      {},
      expecting: { _ in
        [.removal(of: inInbox), .arrival(at: deepInInbox), .removal(of: inOtherInbox)]
      })
    let generation = registry.generation

    #expect(
      registry.takeOwnChanges(under: inbox, ifNoOperationSince: generation)
        == OwnChanges(
          removals: [OwnChanges.path(of: inInbox)], arrivals: [OwnChanges.path(of: deepInInbox)]))
    #expect(registry.takeOwnChanges(under: inbox, ifNoOperationSince: generation) == .empty)
    #expect(
      registry.takeOwnChanges(under: otherInbox, ifNoOperationSince: generation)
        == OwnChanges(removals: [OwnChanges.path(of: inOtherInbox)], arrivals: []))
  }

  @Test("counts concurrent operations: idle only once the last one has finished")
  func countsConcurrentOperations() async throws {
    let first = inbox.appending(path: "scan-1.pdf")
    let second = inbox.appending(path: "scan-2.pdf")
    let firstOperation = await HeldOperation.start(in: registry, expecting: [.removal(of: first)])
    let secondOperation = await HeldOperation.start(
      in: registry, expecting: [.removal(of: second)])

    firstOperation.release()
    try await firstOperation.waitUntilFinished()
    #expect(registry.takeOwnChanges(under: inbox, ifNoOperationSince: registry.generation) == nil)

    secondOperation.release()
    try await completion(of: Task { [registry] in await registry.waitUntilIdle() })
    #expect(
      registry.takeOwnChanges(under: inbox, ifNoOperationSince: registry.generation)
        == OwnChanges(
          removals: [OwnChanges.path(of: first), OwnChanges.path(of: second)], arrivals: []))
  }

  @Test("waits for nothing when no operation is running")
  func waitUntilIdleReturnsAtOnce() async throws {
    try await completion(of: Task { [registry] in await registry.waitUntilIdle() })
  }

  @Test("resumes a waiting task once the running operation has finished")
  func waitUntilIdleResumesAfterOperation() async throws {
    let events = EventLog()
    let operation = await HeldOperation.start(
      in: registry, expecting: [], beforeFinishing: { events.append("operation finished") })

    let waiterStarted = AsyncStream<Void>.makeStream()
    let waiter = Task { [registry] in
      waiterStarted.continuation.yield()
      await registry.waitUntilIdle()
      events.append("idle")
    }
    for await _ in waiterStarted.stream { break }
    operation.release()

    try await completion(of: waiter)
    #expect(events.entries == ["operation finished", "idle"])
  }

  @Test("resumes a waiting task that is cancelled while an operation runs")
  func waitUntilIdleResumesOnCancel() async throws {
    let operation = await HeldOperation.start(in: registry, expecting: [])
    defer { operation.release() }

    let waiter = Task { [registry] in await registry.waitUntilIdle() }
    waiter.cancel()

    try await completion(of: waiter)
    #expect(registry.takeOwnChanges(under: inbox, ifNoOperationSince: registry.generation) == nil)
  }
}

/// The error a failing test operation throws.
private struct OperationFailure: Error, Equatable {
  let reason: String
}

/// An operation run through ``ExpectedChanges/perform(_:expecting:)`` on a thread of its own, held inside the
/// operation until ``release()``.
final class HeldOperation: Sendable {
  private let gate = DispatchSemaphore(value: 0)
  private let finished = AsyncStream<Void>.makeStream()

  /// Starts the operation in `registry` and returns once it runs; `beforeFinishing` runs inside it when released.
  static func start(
    in registry: ExpectedChanges, expecting changes: [ExpectedChange],
    beforeFinishing: @escaping @Sendable () -> Void = {}
  ) async -> HeldOperation {
    let held = HeldOperation()
    await withCheckedContinuation { (started: CheckedContinuation<Void, Never>) in
      Thread {
        registry.perform(
          {
            started.resume()
            held.gate.wait()
            beforeFinishing()
          }, expecting: { _ in changes })
        held.finished.continuation.finish()
      }.start()
    }
    return held
  }

  /// Lets the operation finish.
  func release() {
    gate.signal()
  }

  /// Returns once `perform` has returned on the operation's thread.
  func waitUntilFinished() async throws {
    let finished = finished
    try await completion(of: Task { for await _ in finished.stream {} })
  }
}

/// What happened, in order, from any thread.
private final class EventLog: Sendable {
  private let storage = Mutex<[String]>([])

  var entries: [String] { storage.withLock { $0 } }

  func append(_ entry: String) {
    storage.withLock { $0.append(entry) }
  }
}

/// No result within the timeout.
private struct TimedOut: Error {}

/// Awaits `task`, failing when it does not finish within `timeout`; it is then cancelled.
private func completion(
  of task: Task<Void, Never>, within timeout: Duration = .seconds(10)
) async throws {
  let isFinished = await withTaskGroup(of: Bool.self) { group in
    group.addTask {
      await task.value
      return true
    }
    group.addTask {
      // Cancellation only means the task finished first; either way this child ends without a result.
      try? await Task.sleep(for: timeout)
      return false
    }
    let first = await group.next() ?? false
    if !first { task.cancel() }
    group.cancelAll()
    return first
  }
  guard isFinished else { throw TimedOut() }
}
