import Foundation
import Testing

@testable import DocsortCore

/// Integration tests against the real FSEvents service on temporary folders. Each awaits an expected event with a
/// timeout and never counts events, since FSEvents may merge or repeat them. Nor do they assert that a change made
/// just before watching started stays unreported: FSEvents sometimes delivers such changes after the start.
@Suite("FSEventsSource")
struct FSEventsSourceTests {
  let source = FSEventsSource()

  @Test("reports a file created deep inside a root, under the root's canonical path")
  func reportsFileCreatedDeepInsideRoot() async throws {
    let directory = try TemporaryDirectory()
    let root = try directory.createFolder("Eingang")
    try directory.createFolder("Eingang/A/B/C")
    let paths = StreamRecorder(try source.changedPaths(under: [root]))

    try directory.createFile("Eingang/A/B/C/neu.pdf")

    let path = try await paths.firstElement { $0.hasSuffix("/Eingang/A/B/C/neu.pdf") }
    #expect(path.hasPrefix("/private/var/"))
    #expect(RootMatcher(roots: [root]).roots(affectedBy: path) == [root])
  }

  @Test("reports both names of a renamed file")
  func reportsRename() async throws {
    let directory = try TemporaryDirectory()
    let root = try directory.createFolder("Eingang")
    let original = try directory.createFile("Eingang/alt.pdf")
    let paths = StreamRecorder(try source.changedPaths(under: [root]))

    try FileManager.default.moveItem(at: original, to: root.appending(path: "neu.pdf"))

    try await paths.firstElement { $0.hasSuffix("/Eingang/neu.pdf") }
    try await paths.firstElement { $0.hasSuffix("/Eingang/alt.pdf") }
  }

  @Test("reports the deletion of a root, which the coalescer counts for that root")
  func reportsDeletedRoot() async throws {
    let directory = try TemporaryDirectory()
    let root = try directory.createFolder("Eingang")
    let coalescer = ChangeCoalescer(
      quietInterval: .milliseconds(50), maximumDelay: .seconds(1), clock: ContinuousClock())
    let batches = StreamRecorder(
      coalescer.batches(for: [root], changedPaths: try source.changedPaths(under: [root])))

    // The root's own creation may still be reported after the start, so wait for a change made since, and then for
    // a batch that only the deletion can cause.
    try directory.createFile("Eingang/marker.pdf")
    try await batches.firstElement { $0.contains(root) }
    let batchesBeforeDeletion = batches.elements.count

    try FileManager.default.removeItem(at: root)

    try await batches.firstElement(afterFirst: batchesBeforeDeletion) { $0.contains(root) }
  }

  @Test("reports nothing for a sibling folder outside the roots")
  func ignoresSiblingFolder() async throws {
    let directory = try TemporaryDirectory()
    let root = try directory.createFolder("Eingang")
    try directory.createFolder("Eingang-Nachbar")
    let paths = StreamRecorder(try source.changedPaths(under: [root]))

    try directory.createFile("Eingang-Nachbar/fremd.pdf")
    try directory.createFile("Eingang/marker.pdf")

    try await paths.firstElement { $0.hasSuffix("/Eingang/marker.pdf") }
    #expect(!paths.elements.contains { $0.contains("Eingang-Nachbar") })
  }

  @Test("gives an ended stream for an empty set of roots")
  func endsAtOnceWithoutRoots() async throws {
    var paths = try source.changedPaths(under: []).makeAsyncIterator()

    #expect(await paths.next() == nil)
  }
}
