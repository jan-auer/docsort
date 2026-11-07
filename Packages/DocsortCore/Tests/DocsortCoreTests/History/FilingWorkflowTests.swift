import Foundation
import Testing

@testable import DocsortCore

/// The history driven by real file operations, the way the UI uses the two together.
@Suite("Filing history with file operations")
struct FilingWorkflowTests {
  @Test("filing, renaming and reverting the name are one document whose origin is the inbox file")
  func revertNameViaOrigin() throws {
    let fixture = try FileOperationsFixture()
    let source = try fixture.directory.createFile("Inbox/scan.pdf", contents: "invoice")
    let folder = fixture.archive.appending(path: "Rechnungen", directoryHint: .isDirectory)
    var history = FilingHistory()

    let filed = try fixture.operations.move(
      source, into: folder, named: "Rechnung.pdf", resolution: .refuse)
    let filing = history.recordMove(filed, at: testDate(1))
    let renamed = try fixture.operations.move(
      filed.destinationURL, into: folder, named: "2026-11-07 Rechnung.pdf", resolution: .refuse)
    history.recordMove(renamed, at: testDate(2))

    let origin = try #require(history.origin(ofDocument: filing.documentID))
    let current = try #require(history.currentLocation(ofDocument: filing.documentID))
    let reverted = try fixture.operations.move(
      current, into: current.deletingLastPathComponent(), named: origin.lastPathComponent,
      resolution: .refuse)
    let revert = history.recordMove(reverted, at: testDate(3))

    #expect(revert.documentID == filing.documentID)
    #expect(history.events(ofDocument: filing.documentID).count == 3)
    #expect(history.origin(ofDocument: filing.documentID) == source)
    #expect(origin.lastPathComponent == "scan.pdf")
    #expect(try fixture.contents(of: folder.appending(path: "scan.pdf")) == "invoice")
    #expect(history.document(at: folder.appending(path: "scan.pdf")) == filing.documentID)
  }

  @Test("a move is undone from a reloaded history and its document is back in the inbox")
  func undoAfterReload() throws {
    let fixture = try FileOperationsFixture()
    let source = try fixture.directory.createFile("Inbox/scan.pdf", contents: "invoice")
    let store = FilingHistoryStore(
      fileURL: fixture.directory.url.appending(path: "Support/FilingHistory.json"))
    var history = FilingHistory()
    let filed = try fixture.operations.move(
      source, into: fixture.archive.appending(path: "Rechnungen", directoryHint: .isDirectory),
      named: "Rechnung.pdf", resolution: .refuse)
    let filing = history.recordMove(filed, at: testDate(1))
    try store.save(history)

    var reloaded = try store.load()
    let event = try #require(reloaded.latestActiveEvent(ofDocument: filing.documentID))
    guard case .moved(let record) = event.action else {
      Issue.record("expected a move, got \(event.action)")
      return
    }
    let restored = try fixture.operations.undo(record, resolution: .refuse)
    try reloaded.recordUndo(of: event.id, restoredTo: restored, at: testDate(2))

    #expect(restored.url == source)
    #expect(try fixture.contents(of: source) == "invoice")
    #expect(try fixture.names(in: fixture.archive) == [])
    #expect(reloaded.document(at: source) == filing.documentID)
  }

  @Test(
    "an undo that keeps both records where the file went, so the document can still be followed")
  func undoWithKeepBoth() throws {
    let fixture = try FileOperationsFixture()
    let source = try fixture.directory.createFile("Inbox/scan.pdf", contents: "invoice")
    let folder = fixture.archive.appending(path: "Rechnungen", directoryHint: .isDirectory)
    var history = FilingHistory()
    let filed = try fixture.operations.move(
      source, into: folder, named: "Rechnung.pdf", resolution: .refuse)
    let filing = history.recordMove(filed, at: testDate(1))
    try fixture.directory.createFile("Inbox/scan.pdf", contents: "a new download")

    let restored = try fixture.operations.undo(filed, resolution: .keepBoth)
    try history.recordUndo(of: filing.id, restoredTo: restored, at: testDate(2))

    #expect(restored.url.lastPathComponent == "scan 2.pdf")
    #expect(history.document(at: restored.url) == filing.documentID)
    #expect(history.document(at: source) == nil)
    #expect(history.currentLocation(ofDocument: filing.documentID) == restored.url)
    #expect(history.origin(ofDocument: filing.documentID) == source)

    let refiled = try fixture.operations.move(
      restored.url, into: folder, named: "Rechnung.pdf", resolution: .refuse)
    #expect(history.recordMove(refiled, at: testDate(3)).documentID == filing.documentID)
  }
}
