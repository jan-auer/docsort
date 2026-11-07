import Foundation
import Testing

@testable import DocsortCore

@Suite("FilingHistory")
struct FilingHistoryTests {
  // MARK: - Recording

  @Test("records moves and trashes in the order they happen")
  func recordsInOrder() {
    var history = FilingHistory()
    let move = moveRecord(from: "/Inbox/scan.pdf", to: "/Archiv/Rechnung.pdf")
    let trash = trashRecord(of: "/Inbox/junk.pdf")

    let moved = history.recordMove(move, at: testDate(1))
    let trashed = history.recordTrash(trash, at: testDate(2))

    #expect(history.events == [moved, trashed])
    #expect(moved.action == .moved(move))
    #expect(moved.date == testDate(1))
    #expect(moved.sourceURL == location("/Inbox/scan.pdf"))
    #expect(moved.resultURL == location("/Archiv/Rechnung.pdf"))
    #expect(moved.undoneDate == nil)
    #expect(trashed.action == .trashed(trash))
    #expect(trashed.sourceURL == location("/Inbox/junk.pdf"))
    #expect(trashed.resultURL == location("/Trash/junk.pdf"))
    #expect(moved.documentID != trashed.documentID)
  }

  // MARK: - Linking

  @Test("a move from where a document's chain ends continues that document")
  func linksChain() {
    var history = FilingHistory()
    let first = history.recordMove(
      moveRecord(from: "/Inbox/scan.pdf", to: "/Archiv/a.pdf"), at: testDate(1))
    let second = history.recordMove(
      moveRecord(from: "/Archiv/a.pdf", to: "/Archiv/Rechnungen/b.pdf"), at: testDate(2))
    let third = history.recordTrash(trashRecord(of: "/Archiv/Rechnungen/b.pdf"), at: testDate(3))

    #expect(second.documentID == first.documentID)
    #expect(third.documentID == first.documentID)
    #expect(history.events(ofDocument: first.documentID) == [first, second, third])
  }

  @Test("a move from an unrelated place starts a new document")
  func unrelatedSourceStartsNewDocument() {
    var history = FilingHistory()
    let first = history.recordMove(
      moveRecord(from: "/Inbox/scan.pdf", to: "/Archiv/a.pdf"), at: testDate(1))
    let other = history.recordMove(
      moveRecord(from: "/Inbox/other.pdf", to: "/Archiv/b.pdf"), at: testDate(2))
    let fromOldPlace = history.recordMove(
      moveRecord(from: "/Inbox/scan.pdf", to: "/Archiv/c.pdf"), at: testDate(3))

    #expect(other.documentID != first.documentID)
    #expect(fromOldPlace.documentID != first.documentID)
    #expect(fromOldPlace.documentID != other.documentID)
    #expect(history.events(ofDocument: first.documentID) == [first])
  }

  @Test("locations compare as standardized paths, ignoring a trailing slash")
  func comparesStandardizedPaths() {
    var history = FilingHistory()
    let first = history.recordMove(
      moveRecord(from: "/Inbox/Scan.bundle/", to: "/Archiv/Rechnungen/Scan.bundle/"),
      at: testDate(1))
    let second = history.recordMove(
      moveRecord(from: "/Archiv/./Rechnungen/../Rechnungen/Scan.bundle", to: "/Archiv/Scan.bundle"),
      at: testDate(2))

    #expect(second.documentID == first.documentID)
    #expect(history.document(at: location("/Archiv/Scan.bundle/")) == first.documentID)
  }

  @Test("undone events take no part in linking or locations")
  func undoneEventsExcluded() throws {
    var history = FilingHistory()
    let move = history.recordMove(
      moveRecord(from: "/Inbox/scan.pdf", to: "/Archiv/a.pdf"), at: testDate(1))
    try history.markUndone(move.id, at: testDate(2))

    let fromUndoneResult = history.recordMove(
      moveRecord(from: "/Archiv/a.pdf", to: "/Archiv/b.pdf"), at: testDate(3))

    #expect(fromUndoneResult.documentID != move.documentID)
    #expect(history.document(at: location("/Inbox/scan.pdf")) == move.documentID)
    #expect(history.currentLocation(ofDocument: move.documentID) == location("/Inbox/scan.pdf"))
  }

  @Test("after undoing a chain's latest event, a move from the previous result continues it")
  func continuesAfterUndo() throws {
    var history = FilingHistory()
    let first = history.recordMove(
      moveRecord(from: "/Inbox/scan.pdf", to: "/Archiv/a.pdf"), at: testDate(1))
    let second = history.recordMove(
      moveRecord(from: "/Archiv/a.pdf", to: "/Archiv/b.pdf"), at: testDate(2))
    try history.markUndone(second.id, at: testDate(3))

    #expect(history.currentLocation(ofDocument: first.documentID) == location("/Archiv/a.pdf"))
    let third = history.recordMove(
      moveRecord(from: "/Archiv/a.pdf", to: "/Archiv/c.pdf"), at: testDate(4))

    #expect(third.documentID == first.documentID)
    #expect(
      history.events(ofDocument: first.documentID).map(\.id) == [first.id, second.id, third.id])
    #expect(history.latestActiveEvent(ofDocument: first.documentID)?.id == third.id)
    #expect(history.currentLocation(ofDocument: first.documentID) == location("/Archiv/c.pdf"))
  }

  @Test("after undoing every event, a move from the origin continues the document")
  func continuesFromOriginAfterUndoingAll() throws {
    var history = FilingHistory()
    let first = history.recordMove(
      moveRecord(from: "/Inbox/scan.pdf", to: "/Archiv/a.pdf"), at: testDate(1))
    try history.markUndone(first.id, at: testDate(2))

    #expect(history.latestActiveEvent(ofDocument: first.documentID) == nil)
    let again = history.recordMove(
      moveRecord(from: "/Inbox/scan.pdf", to: "/Archiv/b.pdf"), at: testDate(3))

    #expect(again.documentID == first.documentID)
  }

  // MARK: - Origin

  @Test("the origin is where the document was before its first move")
  func originAfterSeveralMoves() {
    var history = FilingHistory()
    let first = history.recordMove(
      moveRecord(from: "/Inbox/scan.pdf", to: "/Archiv/a.pdf"), at: testDate(1))
    history.recordMove(moveRecord(from: "/Archiv/a.pdf", to: "/Archiv/b.pdf"), at: testDate(2))
    history.recordMove(moveRecord(from: "/Archiv/b.pdf", to: "/Archiv/X/c.pdf"), at: testDate(3))

    #expect(history.origin(ofDocument: first.documentID) == location("/Inbox/scan.pdf"))
  }

  @Test("the origin stays the inbox path after the first move is undone and the file filed again")
  func originAfterUndoingFirst() throws {
    var history = FilingHistory()
    let first = history.recordMove(
      moveRecord(from: "/Inbox/scan.pdf", to: "/Archiv/a.pdf"), at: testDate(1))
    try history.markUndone(first.id, at: testDate(2))

    #expect(history.origin(ofDocument: first.documentID) == location("/Inbox/scan.pdf"))

    history.recordMove(moveRecord(from: "/Inbox/scan.pdf", to: "/Archiv/b.pdf"), at: testDate(3))
    history.recordMove(moveRecord(from: "/Archiv/b.pdf", to: "/Archiv/c.pdf"), at: testDate(4))

    #expect(history.origin(ofDocument: first.documentID) == location("/Inbox/scan.pdf"))
  }

  @Test("an unknown document has no origin, location or events")
  func unknownDocument() {
    var history = FilingHistory()
    history.recordMove(moveRecord(from: "/Inbox/scan.pdf", to: "/Archiv/a.pdf"), at: testDate(1))
    let unknown = UUID()

    #expect(history.origin(ofDocument: unknown) == nil)
    #expect(history.currentLocation(ofDocument: unknown) == nil)
    #expect(history.latestActiveEvent(ofDocument: unknown) == nil)
    #expect(history.events(ofDocument: unknown) == [])
  }

  // MARK: - Document at a location

  @Test(
    "finds the document whose chain ends at a location, and nothing at places it passed through")
  func documentAtLocation() {
    var history = FilingHistory()
    let first = history.recordMove(
      moveRecord(from: "/Inbox/scan.pdf", to: "/Archiv/a.pdf"), at: testDate(1))
    history.recordMove(moveRecord(from: "/Archiv/a.pdf", to: "/Archiv/b.pdf"), at: testDate(2))

    #expect(history.document(at: location("/Archiv/b.pdf")) == first.documentID)
    #expect(history.document(at: location("/Archiv/a.pdf")) == nil)
    #expect(history.document(at: location("/Inbox/scan.pdf")) == nil)
    #expect(history.document(at: location("/Archiv/unknown.pdf")) == nil)
  }

  @Test("when two documents end at the same place, the one changed most recently is there")
  func mostRecentDocumentWins() {
    var history = FilingHistory()
    let replacedDocument = history.recordMove(
      moveRecord(from: "/Inbox/old.pdf", to: "/Archiv/Rechnung.pdf"), at: testDate(1))
    let replacingRecord = MoveRecord(
      originalURL: location("/Inbox/new.pdf"), destinationURL: location("/Archiv/Rechnung.pdf"),
      createdFolders: [],
      replaced: TrashRecord(
        originalURL: location("/Archiv/Rechnung.pdf"),
        trashedURL: location("/Trash/Rechnung.pdf")))
    let replacing = history.recordMove(replacingRecord, at: testDate(2))

    #expect(replacing.documentID != replacedDocument.documentID)
    #expect(history.document(at: location("/Archiv/Rechnung.pdf")) == replacing.documentID)
  }

  // MARK: - Marking undone

  @Test("marking an event undone keeps it in the log with the undo date")
  func markUndoneKeepsEvent() throws {
    var history = FilingHistory()
    let move = history.recordMove(
      moveRecord(from: "/Inbox/scan.pdf", to: "/Archiv/a.pdf"), at: testDate(1))

    try history.markUndone(move.id, at: testDate(5))

    #expect(history.events.count == 1)
    #expect(history.events[0].id == move.id)
    #expect(history.events[0].undoneDate == testDate(5))
  }

  @Test("marking an unknown event undone fails and changes nothing")
  func markUndoneUnknown() {
    var history = FilingHistory()
    history.recordMove(moveRecord(from: "/Inbox/scan.pdf", to: "/Archiv/a.pdf"), at: testDate(1))
    let before = history
    let unknown = UUID()

    #expect(throws: FilingHistoryError.unknownEvent(unknown)) {
      try history.markUndone(unknown, at: testDate(2))
    }
    #expect(history == before)
  }

  @Test("marking an event undone twice fails and keeps the first undo date")
  func markUndoneTwice() throws {
    var history = FilingHistory()
    let move = history.recordMove(
      moveRecord(from: "/Inbox/scan.pdf", to: "/Archiv/a.pdf"), at: testDate(1))
    try history.markUndone(move.id, at: testDate(2))
    let before = history

    #expect(throws: FilingHistoryError.alreadyUndone(move.id, undoneDate: testDate(2))) {
      try history.markUndone(move.id, at: testDate(3))
    }
    #expect(history == before)
  }

  @Test("an event cannot be marked undone while a later event of its document is active")
  func markUndoneRefusesEarlierEvent() throws {
    var history = FilingHistory()
    let first = history.recordMove(
      moveRecord(from: "/Inbox/scan.pdf", to: "/Archiv/a.pdf"), at: testDate(1))
    let second = history.recordMove(
      moveRecord(from: "/Archiv/a.pdf", to: "/Archiv/b.pdf"), at: testDate(2))
    let before = history

    #expect(throws: FilingHistoryError.laterEventActive(first.id, later: second.id)) {
      try history.markUndone(first.id, at: testDate(3))
    }
    #expect(history == before)

    try history.markUndone(second.id, at: testDate(4))
    try history.markUndone(first.id, at: testDate(5))
    #expect(history.events.map(\.undoneDate) == [testDate(5), testDate(4)])
  }

  @Test("events of other documents do not block marking an event undone")
  func markUndoneIgnoresOtherDocuments() throws {
    var history = FilingHistory()
    let first = history.recordMove(
      moveRecord(from: "/Inbox/scan.pdf", to: "/Archiv/a.pdf"), at: testDate(1))
    history.recordMove(moveRecord(from: "/Inbox/other.pdf", to: "/Archiv/b.pdf"), at: testDate(2))

    try history.markUndone(first.id, at: testDate(3))

    #expect(history.events[0].undoneDate == testDate(3))
  }
}
