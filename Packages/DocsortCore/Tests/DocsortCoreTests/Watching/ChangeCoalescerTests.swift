import Foundation
import Testing

@testable import DocsortCore

@Suite("ChangeCoalescer", .timeLimit(.minutes(1)))
struct ChangeCoalescerTests {
  let inbox = URL(filePath: "/Volumes/Archiv/Eingang", directoryHint: .isDirectory)
  let scans = URL(filePath: "/Volumes/Archiv/Scans", directoryHint: .isDirectory)
  /// A root that only the "still pending" checks send events for.
  let probe = URL(filePath: "/Volumes/Probe", directoryHint: .isDirectory)

  @Test("flushes a single change once the quiet interval has passed")
  func flushesAfterQuietInterval() async {
    var harness = Harness(roots: [inbox, scans, probe])

    await harness.send("/Volumes/Archiv/Eingang/neu.pdf", at: .zero)
    await harness.advance(to: .milliseconds(500))

    #expect(await harness.nextBatch() == [inbox])
    #expect(await harness.remainingBatches() == [])
  }

  @Test("holds a change until the quiet interval has passed")
  func holdsChangeDuringQuietInterval() async {
    var harness = Harness(roots: [inbox, scans, probe])

    await harness.send("/Volumes/Archiv/Eingang/neu.pdf", at: .zero)
    await harness.advance(to: .milliseconds(499))

    #expect(await harness.stillPending() == [inbox, probe])
  }

  @Test("merges a burst of changes within the quiet interval into one batch")
  func mergesBurst() async {
    var harness = Harness(roots: [inbox, scans, probe])

    await harness.send("/Volumes/Archiv/Eingang/a.pdf", at: .zero)
    await harness.send("/Volumes/Archiv/Eingang/b.pdf", at: .milliseconds(300))
    await harness.send("/Volumes/Archiv/Eingang/A/c.pdf", at: .milliseconds(600))
    await harness.advance(to: .milliseconds(1_099))
    #expect(await harness.stillPending() == [inbox, probe])
  }

  @Test("flushes a burst once the quiet interval after its last change has passed")
  func flushesBurstAfterLastChange() async {
    var harness = Harness(roots: [inbox, scans, probe])

    await harness.send("/Volumes/Archiv/Eingang/a.pdf", at: .zero)
    await harness.send("/Volumes/Archiv/Eingang/b.pdf", at: .milliseconds(300))
    await harness.send("/Volumes/Archiv/Eingang/A/c.pdf", at: .milliseconds(600))
    await harness.advance(to: .milliseconds(1_100))

    #expect(await harness.nextBatch() == [inbox])
    #expect(await harness.remainingBatches() == [])
  }

  @Test("flushes continuous changes once the maximum delay has passed")
  func flushesAtMaximumDelay() async {
    var harness = Harness(roots: [inbox, scans, probe])

    for step in 0..<8 {
      await harness.send("/Volumes/Archiv/Eingang/teil-\(step).pdf", at: .milliseconds(400 * step))
    }
    await harness.advance(to: .seconds(3))

    #expect(await harness.nextBatch() == [inbox])
    #expect(await harness.remainingBatches() == [])
  }

  @Test("holds continuous changes until the maximum delay has passed")
  func holdsContinuousChangesUntilMaximumDelay() async {
    var harness = Harness(roots: [inbox, scans, probe])

    for step in 0..<8 {
      await harness.send("/Volumes/Archiv/Eingang/teil-\(step).pdf", at: .milliseconds(400 * step))
    }
    await harness.advance(to: .milliseconds(2_999))

    #expect(await harness.stillPending() == [inbox, probe])
  }

  @Test("starts a new delay for changes after a flush")
  func startsAfreshAfterFlush() async {
    var harness = Harness(roots: [inbox, scans, probe])

    await harness.send("/Volumes/Archiv/Eingang/a.pdf", at: .zero)
    await harness.advance(to: .milliseconds(500))
    #expect(await harness.nextBatch() == [inbox])

    // Nothing is pending, so no timer waits on the clock.
    harness.clock.advance(to: .seconds(1))
    await harness.send("/Volumes/Archiv/Eingang/b.pdf", at: .seconds(1))
    await harness.advance(to: .milliseconds(1_500))

    #expect(await harness.nextBatch() == [inbox])
    #expect(await harness.remainingBatches() == [])
  }

  @Test("times each root independently")
  func timesRootsIndependently() async {
    var harness = Harness(roots: [inbox, scans, probe])

    await harness.send("/Volumes/Archiv/Eingang/a.pdf", at: .zero)
    await harness.send("/Volumes/Archiv/Scans/b.pdf", at: .milliseconds(300))
    await harness.advance(to: .milliseconds(500))
    #expect(await harness.nextBatch() == [inbox])

    await harness.advance(to: .milliseconds(799))
    #expect(await harness.stillPending() == [scans, probe])
  }

  @Test("flushes a later root once its own quiet interval has passed")
  func flushesLaterRootOnItsOwnTime() async {
    var harness = Harness(roots: [inbox, scans, probe])

    await harness.send("/Volumes/Archiv/Eingang/a.pdf", at: .zero)
    await harness.send("/Volumes/Archiv/Scans/b.pdf", at: .milliseconds(300))
    await harness.advance(to: .milliseconds(500))
    #expect(await harness.nextBatch() == [inbox])
    await harness.advance(to: .milliseconds(800))

    #expect(await harness.nextBatch() == [scans])
    #expect(await harness.remainingBatches() == [])
  }

  @Test("flushes roots that become due at the same moment in one batch")
  func flushesSimultaneousRootsTogether() async {
    var harness = Harness(roots: [inbox, scans, probe])

    await harness.send("/Volumes/Archiv/Eingang/a.pdf", at: .zero)
    await harness.send("/Volumes/Archiv/Scans/b.pdf", at: .zero)
    await harness.advance(to: .milliseconds(500))

    #expect(await harness.nextBatch() == [inbox, scans])
    #expect(await harness.remainingBatches() == [])
  }

  @Test(
    "counts a change at, inside or above a root for that root",
    arguments: [
      "/Volumes/Archiv/Eingang",
      "/Volumes/Archiv/Eingang/",
      "/Volumes/Archiv/Eingang/neu.pdf",
      "/Volumes/Archiv/Eingang/A/B/neu.pdf",
    ])
  func countsChangeAtOrInsideRoot(path: String) async {
    var harness = Harness(roots: [inbox, scans])

    await harness.send(path, at: .zero)

    #expect(await harness.remainingBatches() == [[inbox]])
  }

  @Test(
    "counts a change to an ancestor for every root below it",
    arguments: ["/Volumes/Archiv", "/Volumes", "/"])
  func countsAncestorChangeForRootsBelow(path: String) async {
    var harness = Harness(roots: [inbox, scans])

    await harness.send(path, at: .zero)

    #expect(await harness.remainingBatches() == [[inbox, scans]])
  }

  @Test(
    "ignores changes outside every root",
    arguments: [
      "/Volumes/Archiv/Eingang2/neu.pdf",
      "/Volumes/Archiv/Ablage/neu.pdf",
      "/Volumes/Andere",
      "/Volumes/Archiv/Eingang.pdf",
    ])
  func ignoresUnrelatedChanges(path: String) async {
    var harness = Harness(roots: [inbox, scans])

    await harness.send(path, at: .zero)

    #expect(await harness.remainingBatches() == [])
  }

  @Test("matches a canonical /private/var path to a root given under /var")
  func matchesCanonicalPathOfRoot() async throws {
    let directory = try TemporaryDirectory()
    let root = try directory.createFolder("Eingang")
    let givenPath = root.path(percentEncoded: false)
    try #require(givenPath.hasPrefix("/var/"))
    var harness = Harness(roots: [root])

    await harness.send("/private\(givenPath)neu.pdf", at: .zero)

    #expect(await harness.remainingBatches() == [[root]])
  }

  @Test("matches a root that does not exist yet through the real path of its parent")
  func matchesMissingRootThroughParent() async throws {
    let directory = try TemporaryDirectory()
    let root = directory.url.appending(path: "Noch nicht da/Eingang", directoryHint: .isDirectory)
    let givenPath = root.path(percentEncoded: false)
    try #require(givenPath.hasPrefix("/var/"))
    var harness = Harness(roots: [root])

    await harness.send("/private\(givenPath)neu.pdf", at: .zero)
    await harness.send("\(givenPath)", at: .zero)

    #expect(await harness.remainingBatches() == [[root]])
  }

  @Test("matches paths that spell a root's name in another Unicode normalisation")
  func matchesAcrossUnicodeNormalisation() async {
    let composed = URL(filePath: "/Volumes/Archiv/Bel\u{E4}ge", directoryHint: .isDirectory)
    var harness = Harness(roots: [composed])

    await harness.send("/Volumes/Archiv/Bela\u{308}ge/neu.pdf", at: .zero)

    #expect(await harness.remainingBatches() == [[composed]])
  }

  @Test("flushes pending changes at once and finishes when the changes end")
  func flushesPendingWhenInputEnds() async {
    var harness = Harness(roots: [inbox, scans])

    await harness.send("/Volumes/Archiv/Eingang/a.pdf", at: .zero)
    await harness.send("/Volumes/Archiv/Scans/b.pdf", at: .milliseconds(200))
    await harness.source.finish()

    #expect(await harness.nextBatch() == [inbox, scans])
    #expect(await harness.nextBatch() == nil)
  }

  @Test("cancelling the consumer ends the batches, stops the timer and stops watching")
  func cancellationStopsEverything() async {
    let clock = ManualClock()
    let source = FakeFolderEventSource()
    let coalescer = ChangeCoalescer(
      quietInterval: .milliseconds(500), maximumDelay: .seconds(3), clock: clock)
    let batches = coalescer.batches(
      for: [inbox], changedPaths: source.changedPaths(under: [inbox]))
    let consumer = Task {
      var received: [Set<URL>] = []
      for await batch in batches {
        received.append(batch)
      }
      return received
    }

    await source.send("/Volumes/Archiv/Eingang/a.pdf")
    await clock.waitForSleepers(1)
    consumer.cancel()

    #expect(await consumer.value == [])
    await clock.waitForSleepers(0)
    await source.waitUntilTerminated()
  }

  @Test("dropping the batches stops watching")
  func droppingBatchesStopsWatching() async {
    let source = FakeFolderEventSource()
    let coalescer = ChangeCoalescer(
      quietInterval: .milliseconds(500), maximumDelay: .seconds(3), clock: ManualClock())
    _ = coalescer.batches(for: [inbox], changedPaths: source.changedPaths(under: [inbox]))

    await source.waitUntilTerminated()
  }
}

/// A coalescer fed by a fake source and timed by a manual clock (quiet interval 0.5 s, maximum delay 3 s).
private struct Harness {
  let clock = ManualClock()
  let source = FakeFolderEventSource()
  let roots: Set<URL>
  private var batches: AsyncStream<Set<URL>>.Iterator

  init(roots: Set<URL>) {
    self.roots = roots
    let coalescer = ChangeCoalescer(
      quietInterval: .milliseconds(500), maximumDelay: .seconds(3), clock: clock)
    batches = coalescer.batches(for: roots, changedPaths: source.changedPaths(under: roots))
      .makeAsyncIterator()
  }

  /// Moves the clock to `offset` (if it is not there yet) and sends `path` at that time.
  func send(_ path: String, at offset: Duration) async {
    if clock.now.offset < offset {
      await advance(to: offset)
    }
    await source.send(path)
  }

  /// Moves the clock to `offset` once the coalescer's timer is waiting on it. Only for moments when a change is
  /// pending; otherwise no timer waits.
  func advance(to offset: Duration) async {
    await clock.waitForSleepers(1)
    clock.advance(to: offset)
  }

  mutating func nextBatch() async -> Set<URL>? {
    await batches.next()
  }

  /// Ends the input and returns every batch still to come, including the final flush.
  mutating func remainingBatches() async -> [Set<URL>] {
    await source.finish()
    var remaining: [Set<URL>] = []
    while let batch = await batches.next() {
      remaining.append(batch)
    }
    return remaining
  }

  /// The roots still pending, as revealed by sending a change for ``probe`` and ending the input: the final flush
  /// holds every pending root at once, so a root that was flushed earlier shows up in a batch of its own.
  mutating func stillPending() async -> Set<URL>? {
    await source.send("/Volumes/Probe/probe.pdf")
    let remaining = await remainingBatches()
    guard remaining.count == 1 else { return nil }
    return remaining.first
  }
}
