import Foundation
import Synchronization
import Testing

@testable import DocsortCore

/// The watcher against a fake event source and a manual clock (quiet interval 0.5 s, maximum delay 3 s, retry
/// interval 5 s), on real folders: scanning is real. Updates are awaited with a timeout; the clock only moves once the
/// expected sleepers wait on it.
@Suite("InboxWatcher", .timeLimit(.minutes(1)))
struct InboxWatcherTests {
  let directory: TemporaryDirectory
  let scans: WatchedInbox
  let downloads: WatchedInbox
  let expectedChanges = ExpectedChanges()
  let clock = ManualClock()
  let source = FakeFolderEventSource()

  init() throws {
    directory = try TemporaryDirectory()
    try directory.createFile("Scans/scan-1.pdf", modified: testDate(10))
    try directory.createFile("Downloads/statement-1.pdf", modified: testDate(20))
    scans = WatchedInbox(id: UUID(), folder: directory.url.appending(path: "Scans/"))
    downloads = WatchedInbox(id: UUID(), folder: directory.url.appending(path: "Downloads/"))
  }

  @Test("starts watching every inbox, then delivers each inbox's listing in order, without changes")
  func initialUpdates() async throws {
    let updates = watch([scans, downloads])

    #expect(
      try await updates.update(1)
        == InboxUpdate(inboxID: scans.id, state: try currentState(of: scans), changes: []))
    #expect(source.watchedRoots == [[scans.folder, downloads.folder]])
    #expect(
      try await updates.update(2)
        == InboxUpdate(inboxID: downloads.id, state: try currentState(of: downloads), changes: []))
  }

  @Test("delivers an inbox missing at the start as unreachable, and the other inbox as listed")
  func unreachableAtStart() async throws {
    let missing = WatchedInbox(id: UUID(), folder: directory.url.appending(path: "Missing/"))
    let updates = watch([scans, missing])

    #expect(
      try await updates.update(1)
        == InboxUpdate(inboxID: scans.id, state: try currentState(of: scans), changes: []))
    #expect(
      try await updates.update(2)
        == InboxUpdate(
          inboxID: missing.id, state: .unreachable(.notFound(missing.folder)), changes: []))
  }

  @Test("reports a file that arrives once its folder has been quiet")
  func reportsArrival() async throws {
    let updates = watch([scans, downloads])
    try await updates.update(2)

    let arrived = try directory.createFile("Scans/scan-2.pdf", modified: testDate(30))
    await reportChange(at: arrived)

    let listing = try currentListing(of: scans)
    #expect(
      try await updates.update(3)
        == InboxUpdate(
          inboxID: scans.id, state: .listed(listing),
          changes: [.arrived(try item("scan-2.pdf", in: listing))]))
  }

  @Test("reports a file removed outside docsort")
  func reportsRemoval() async throws {
    let updates = watch([scans, downloads])
    let before = try #require(try await updates.update(1).state.listing)
    try await updates.update(2)

    let removed = scans.folder.appending(path: "scan-1.pdf")
    try FileManager.default.removeItem(at: removed)
    await reportChange(at: removed)

    #expect(
      try await updates.update(3)
        == InboxUpdate(
          inboxID: scans.id, state: try currentState(of: scans),
          changes: [.removed(try item("scan-1.pdf", in: before))]))
  }

  @Test("reports a file renamed outside docsort as a change of the same file")
  func reportsRename() async throws {
    let updates = watch([scans, downloads])
    let before = try #require(try await updates.update(1).state.listing)
    try await updates.update(2)

    let original = scans.folder.appending(path: "scan-1.pdf")
    try FileManager.default.moveItem(
      at: original, to: scans.folder.appending(path: "invoice-1.pdf"))
    await reportChange(at: original)

    let listing = try currentListing(of: scans)
    #expect(
      try await updates.update(3)
        == InboxUpdate(
          inboxID: scans.id, state: .listed(listing),
          changes: [
            .changed(
              from: try item("scan-1.pdf", in: before), to: try item("invoice-1.pdf", in: listing))
          ]))
  }

  @Test("delivers the listing after docsort's own move, without reporting the move as a change")
  func ownMoveIsNotAChange() async throws {
    let archive = try directory.createFolder("Archive")
    let updates = watch([scans, downloads])
    try await updates.update(2)

    let filed = scans.folder.appending(path: "scan-1.pdf")
    _ = try expectedChanges.perform(
      { () throws(FileOperationError) -> MoveRecord in
        try FileOperations().move(filed, into: archive, named: "scan-1.pdf", resolution: .refuse)
      },
      expecting: { record in [.removal(of: record.originalURL)] })
    await reportChange(at: filed)

    let update = try await updates.update(3)
    #expect(
      update == InboxUpdate(inboxID: scans.id, state: try currentState(of: scans), changes: []))
    #expect(try #require(update.state.listing).items.isEmpty)
  }

  @Test("holds a batch while an operation runs, then leaves the operation's change out")
  func holdsBatchDuringOperation() async throws {
    let archive = try directory.createFolder("Archive")
    let updates = watch([scans, downloads])
    try await updates.update(2)

    let filed = scans.folder.appending(path: "scan-1.pdf")
    let operation = await HeldOperation.start(in: expectedChanges, expecting: [.removal(of: filed)])
    try FileManager.default.moveItem(at: filed, to: archive.appending(path: "scan-1.pdf"))
    try directory.createFile("Scans/scan-2.pdf", modified: testDate(30))
    await reportChange(at: filed)
    #expect(updates.elements.count == 2)

    operation.release()

    let listing = try currentListing(of: scans)
    #expect(
      try await updates.update(3)
        == InboxUpdate(
          inboxID: scans.id, state: .listed(listing),
          changes: [.arrived(try item("scan-2.pdf", in: listing))]))
  }

  @Test("delivers nothing for an event that changed nothing")
  func eventWithoutChange() async throws {
    let updates = watch([scans, downloads])
    try await updates.update(2)

    await reportChange(at: scans.folder)
    let arrived = try directory.createFile("Downloads/statement-2.pdf", modified: testDate(30))
    await reportChange(at: arrived)

    let update = try await updates.update(3)
    #expect(update.inboxID == downloads.id)
    #expect(
      update.changes == [
        .arrived(try item("statement-2.pdf", in: try currentListing(of: downloads)))
      ])
  }

  @Test(
    "reports a deleted inbox as unreachable, and lists it again once it is back, watching it anew")
  func deletedInboxRecovers() async throws {
    let updates = watch([scans, downloads])
    try await updates.update(2)

    try FileManager.default.removeItem(at: scans.folder)
    await reportChange(at: scans.folder)
    #expect(
      try await updates.update(3)
        == InboxUpdate(
          inboxID: scans.id, state: .unreachable(.notFound(scans.folder)), changes: []))

    try directory.createFile("Scans/scan-2.pdf", modified: testDate(30))
    await clock.waitForSleepers(1)
    clock.advance(to: clock.now.offset + .seconds(5))

    #expect(
      try await updates.update(4)
        == InboxUpdate(inboxID: scans.id, state: try currentState(of: scans), changes: []))
    #expect(
      source.watchedRoots == [
        [scans.folder, downloads.folder], [scans.folder, downloads.folder],
      ])
  }

  @Test("rescans every inbox after a restart, so changes the old watch still held are not lost")
  func restartKeepsHeldChanges() async throws {
    let missing = WatchedInbox(id: UUID(), folder: directory.url.appending(path: "Missing/"))
    let updates = watch([scans, missing])
    try await updates.update(2)
    await clock.waitForSleepers(1)

    // A change in Scans is held until 5.3 s; the retry at 5 s finds Missing back and restarts the watch first.
    clock.advance(to: .milliseconds(4800))
    try directory.createFile("Missing/letter-1.pdf", modified: testDate(40))
    let arrived = try directory.createFile("Scans/scan-2.pdf", modified: testDate(30))
    await source.send(arrived.path(percentEncoded: false))
    await clock.waitForSleepers(2)
    clock.advance(to: .seconds(5))

    #expect(
      try await updates.update(3)
        == InboxUpdate(inboxID: missing.id, state: try currentState(of: missing), changes: []))
    let listing = try currentListing(of: scans)
    #expect(
      try await updates.update(4)
        == InboxUpdate(
          inboxID: scans.id, state: .listed(listing),
          changes: [.arrived(try item("scan-2.pdf", in: listing))]))
    #expect(
      source.watchedRoots == [[scans.folder, missing.folder], [scans.folder, missing.folder]])
    #expect(!source.isTerminated)
  }

  @Test("lists the inboxes when watching cannot start, and rescans them until it can")
  func eventSourceFailingToStart() async throws {
    let flakySource = FlakyEventSource(failingStarts: 2, then: source)
    let updates = watch([scans, downloads], eventSource: flakySource)
    #expect(try await updates.update(1).state == (try currentState(of: scans)))
    #expect(try await updates.update(2).state == (try currentState(of: downloads)))

    try directory.createFile("Scans/scan-2.pdf", modified: testDate(30))
    await clock.waitForSleepers(1)
    clock.advance(to: .seconds(5))

    let listing = try currentListing(of: scans)
    #expect(
      try await updates.update(3)
        == InboxUpdate(
          inboxID: scans.id, state: .listed(listing),
          changes: [.arrived(try item("scan-2.pdf", in: listing))]))
    #expect(flakySource.startAttempts == 2)

    // The third attempt starts the watch, and the retry rescans every inbox once more. The file is created once the
    // next retry waits, so the second retry has finished scanning, and before that retry, so no scan sees it half
    // written.
    await clock.waitForSleepers(1)
    try directory.createFile("Downloads/statement-2.pdf", modified: testDate(40))
    clock.advance(to: .seconds(10))

    let retried = try await updates.update(4)
    #expect(retried.inboxID == downloads.id)
    #expect(
      retried.changes == [
        .arrived(try item("statement-2.pdf", in: try currentListing(of: downloads)))
      ])
    #expect(flakySource.startAttempts == 3)

    // Downloads is the last inbox, so the retry has finished. From now on events drive the rescans: only the
    // coalescer's timer waits on the clock, no retry is scheduled.
    let arrived = try directory.createFile("Downloads/statement-3.pdf", modified: testDate(50))
    await reportChange(at: arrived)

    let update = try await updates.update(5)
    #expect(update.inboxID == downloads.id)
    #expect(
      update.changes == [
        .arrived(try item("statement-3.pdf", in: try currentListing(of: downloads)))
      ])
    #expect(flakySource.startAttempts == 3)
  }

  @Test("stops watching, retrying and scanning when the consumer stops")
  func consumerStoppingEndsWatching() async throws {
    let missing = WatchedInbox(id: UUID(), folder: directory.url.appending(path: "Missing/"))
    var updates: StreamRecorder<InboxUpdate>? = watch([scans, missing])
    try await updates?.update(2)
    await clock.waitForSleepers(1)

    updates = nil

    await source.waitUntilTerminated()
    await clock.waitForSleepers(0)
  }

  /// Watches `inboxes` through `eventSource` (the fake ``source`` by default) and records the updates.
  private func watch(
    _ inboxes: [WatchedInbox], eventSource: (any FolderEventSource)? = nil
  ) -> StreamRecorder<InboxUpdate> {
    let timing = WatchTiming(
      quietInterval: .milliseconds(500), maximumDelay: .seconds(3), retryInterval: .seconds(5),
      clock: clock)
    let watcher = InboxWatcher(
      expectedChanges: expectedChanges, timing: timing, eventSource: eventSource ?? source)
    return StreamRecorder(watcher.updates(for: inboxes))
  }

  /// Reports a change at `url` and lets the quiet interval pass, once the coalescer's timer waits on the clock.
  private func reportChange(at url: URL) async {
    await source.send(url.path(percentEncoded: false))
    await clock.waitForSleepers(1)
    clock.advance(to: clock.now.offset + .milliseconds(500))
  }

  private func currentListing(of inbox: WatchedInbox) throws -> InboxListing {
    try InboxScanner().scan(inbox.folder)
  }

  private func currentState(of inbox: WatchedInbox) throws -> InboxState {
    .listed(try currentListing(of: inbox))
  }
}

/// End-to-end tests with the real FSEvents service and clock on temporary folders. Each awaits the expected update
/// with a timeout and ignores any others, since FSEvents may deliver changes made just before watching started.
@Suite("InboxWatcher with FSEvents")
struct InboxWatcherFSEventsTests {
  let directory: TemporaryDirectory
  let inbox: WatchedInbox
  let watcher = InboxWatcher(
    expectedChanges: ExpectedChanges(),
    timing: WatchTiming(
      quietInterval: .milliseconds(50), maximumDelay: .milliseconds(500), retryInterval: .seconds(5)
    ))

  init() throws {
    directory = try TemporaryDirectory()
    inbox = WatchedInbox(id: UUID(), folder: try directory.createFolder("Scans"))
  }

  @Test("reports a file created in an inbox as arrived")
  func reportsArrival() async throws {
    let updates = StreamRecorder(watcher.updates(for: [inbox]))
    try await updates.update(1)

    try directory.createFile("Scans/scan-1.pdf", modified: testDate(10))

    try await updates.firstElement { update in
      update.changes.contains { change in
        guard case .arrived(let item) = change else { return false }
        return item.name == "scan-1.pdf"
      }
    }
  }

  @Test("reports a file renamed in an inbox as changed")
  func reportsRename() async throws {
    let original = try directory.createFile("Scans/scan-1.pdf", modified: testDate(10))
    let updates = StreamRecorder(watcher.updates(for: [inbox]))
    try await updates.update(1)

    try FileManager.default.moveItem(
      at: original, to: inbox.folder.appending(path: "invoice-1.pdf"))

    try await updates.firstElement { update in
      update.changes.contains { change in
        guard case .changed(let old, let new) = change else { return false }
        return old.name == "scan-1.pdf" && new.name == "invoice-1.pdf"
      }
    }
  }
}

/// An event source that fails to start a given number of times, then hands out `source`'s streams.
private final class FlakyEventSource: FolderEventSource {
  private let remainingFailures: Mutex<Int>
  private let attempts = Mutex(0)
  private let source: FakeFolderEventSource

  init(failingStarts: Int, then source: FakeFolderEventSource) {
    remainingFailures = Mutex(failingStarts)
    self.source = source
  }

  /// How often watching was asked to start.
  var startAttempts: Int { attempts.withLock { $0 } }

  func changedPaths(under roots: Set<URL>) throws(FolderWatchError) -> AsyncStream<String> {
    attempts.withLock { $0 += 1 }
    let fails = remainingFailures.withLock { remaining in
      guard remaining > 0 else { return false }
      remaining -= 1
      return true
    }
    if fails { throw .streamNotStarted(roots: roots) }
    return source.changedPaths(under: roots)
  }
}

extension StreamRecorder where Element == InboxUpdate {
  /// The update at `position`, counting from 1, waiting up to 10 seconds for it.
  @discardableResult
  fileprivate func update(_ position: Int) async throws -> InboxUpdate {
    try await firstElement(afterFirst: position - 1) { _ in true }
  }
}

extension InboxState {
  /// The listing of a listed inbox; `nil` for an unreachable one.
  fileprivate var listing: InboxListing? {
    guard case .listed(let listing) = self else { return nil }
    return listing
  }
}
