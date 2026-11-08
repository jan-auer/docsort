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
      filed.destinationURL, into: folder, named: "2034-03-14 Rechnung.pdf", resolution: .refuse)
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

  @Test("after a Replace both documents are where their files are, before and after undoing it")
  func replaceAndUndo() throws {
    let fixture = try FileOperationsFixture()
    let fileA = try fixture.directory.createFile("Inbox/a.pdf", contents: "A")
    let fileB = try fixture.directory.createFile("Inbox/b.pdf", contents: "B")
    let target = fixture.archive.appending(path: "x.pdf")
    var history = FilingHistory()
    let movedA = try fixture.operations.move(
      fileA, into: fixture.archive, named: "x.pdf", resolution: .refuse)
    let filingA = history.recordMove(movedA, at: testDate(1))
    let movedB = try fixture.operations.move(
      fileB, into: fixture.archive, named: "x.pdf", resolution: .replace)
    let filingB = history.recordMove(movedB, at: testDate(2))
    let trashedA = try #require(movedB.replaced)

    #expect(history.document(at: target) == filingB.documentID)
    #expect(history.document(at: trashedA.trashedURL) == filingA.documentID)
    #expect(history.currentLocation(ofDocument: filingA.documentID) == trashedA.trashedURL)
    #expect(history.undoBlocker(for: filingA.id) != nil)
    #expect(fixture.operations.undoBlocker(for: movedA) == .differentItem(at: target))

    #expect(history.undoBlocker(for: filingB.id) == nil)
    let restoredB = try fixture.operations.undo(movedB, resolution: .refuse)
    try history.recordUndo(of: filingB.id, restoredTo: restoredB, at: testDate(3))

    #expect(history.document(at: target) == filingA.documentID)
    #expect(history.document(at: fileB) == filingB.documentID)
    #expect(history.currentLocation(ofDocument: filingA.documentID) == target)
    #expect(try fixture.contents(of: target) == "A")
    #expect(try fixture.contents(of: fileB) == "B")

    #expect(history.undoBlocker(for: filingA.id) == nil)
    let restoredA = try fixture.operations.undo(movedA, resolution: .refuse)
    try history.recordUndo(of: filingA.id, restoredTo: restoredA, at: testDate(4))

    #expect(history.document(at: fileA) == filingA.documentID)
    #expect(try fixture.contents(of: fileA) == "A")
    #expect(try fixture.names(in: fixture.archive) == [])
  }
}
