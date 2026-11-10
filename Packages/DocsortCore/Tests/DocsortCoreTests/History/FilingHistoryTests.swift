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
    let first = history.recordMove(
      moveRecord(from: "/Inbox/old.pdf", to: "/Archiv/Rechnung.pdf"), at: testDate(1))
    // The first file was removed outside the app, and another one filed under its name.
    let second = history.recordMove(
      moveRecord(from: "/Inbox/new.pdf", to: "/Archiv/Rechnung.pdf"), at: testDate(2))

    #expect(second.documentID != first.documentID)
    #expect(history.document(at: location("/Archiv/Rechnung.pdf")) == second.documentID)
  }

  // MARK: - Replace

  /// A move to `/Archiv/x.pdf` that replaced the item there.
  private func replacingMove(from source: String) -> MoveRecord {
    MoveRecord(
      originalURL: location(source), destinationURL: location("/Archiv/x.pdf"), createdFolders: [],
      replaced: trashRecord(of: "/Archiv/x.pdf"), movedItem: testIdentity)
  }

  @Test("a Replace records the trashed item as an event of the document that was there")
  func replaceRecordsTrashOfReplacedDocument() throws {
    var history = FilingHistory()
    let filingA = history.recordMove(
      moveRecord(from: "/Inbox/a.pdf", to: "/Archiv/x.pdf"), at: testDate(1))
    let replacing = replacingMove(from: "/Inbox/b.pdf")

    let filingB = history.recordMove(replacing, at: testDate(2))

    let trashing = try #require(history.events.first { $0.causedBy == filingB.id })
    #expect(trashing.documentID == filingA.documentID)
    #expect(trashing.action == .trashed(try #require(replacing.replaced)))
    #expect(trashing.date == testDate(2))
    #expect(filingB.documentID != filingA.documentID)
    #expect(filingB.causedBy == nil)
    #expect(history.events.count == 3)
    #expect(history.document(at: location("/Archiv/x.pdf")) == filingB.documentID)
    #expect(history.document(at: location("/Trash/x.pdf")) == filingA.documentID)
    #expect(history.currentLocation(ofDocument: filingA.documentID) == location("/Trash/x.pdf"))
    #expect(history.currentLocation(ofDocument: filingB.documentID) == location("/Archiv/x.pdf"))
  }

  @Test("replacing an item no document is at starts a new document for it")
  func replaceOfUnknownItem() throws {
    var history = FilingHistory()

    let filing = history.recordMove(replacingMove(from: "/Inbox/b.pdf"), at: testDate(1))

    let trashing = try #require(history.events.first { $0.causedBy == filing.id })
    #expect(trashing.documentID != filing.documentID)
    #expect(history.origin(ofDocument: trashing.documentID) == location("/Archiv/x.pdf"))
  }

  @Test("undoing a Replace also undoes its trash event, so both documents are back in place")
  func undoReplaceUndoesTrash() throws {
    var history = FilingHistory()
    let filingA = history.recordMove(
      moveRecord(from: "/Inbox/a.pdf", to: "/Archiv/x.pdf"), at: testDate(1))
    let filingB = history.recordMove(replacingMove(from: "/Inbox/b.pdf"), at: testDate(2))
    let trashing = try #require(history.events.first { $0.causedBy == filingB.id })

    try history.recordUndo(
      of: filingB.id,
      restoredTo: RestoredItem(url: location("/Inbox/b.pdf"), identity: testIdentity),
      at: testDate(3))

    #expect(history.events.first { $0.id == trashing.id }?.undoneDate == testDate(3))
    #expect(history.document(at: location("/Archiv/x.pdf")) == filingA.documentID)
    #expect(history.document(at: location("/Inbox/b.pdf")) == filingB.documentID)
    #expect(history.currentLocation(ofDocument: filingA.documentID) == location("/Archiv/x.pdf"))
    #expect(history.undoBlocker(for: filingA.id) == nil)
  }

  @Test("the trash event of a Replace cannot be undone on its own")
  func replaceTrashNotUndoneAlone() throws {
    var history = FilingHistory()
    history.recordMove(moveRecord(from: "/Inbox/a.pdf", to: "/Archiv/x.pdf"), at: testDate(1))
    let filingB = history.recordMove(replacingMove(from: "/Inbox/b.pdf"), at: testDate(2))
    let trashing = try #require(history.events.first { $0.causedBy == filingB.id })
    let before = history

    #expect(
      history.undoBlocker(for: trashing.id)
        == .undoneWithMove(trashing.id, move: filingB.id, undoFirst: filingB.id))
    #expect(
      throws: FilingHistoryError.undoneWithMove(
        trashing.id, move: filingB.id, undoFirst: filingB.id)
    ) {
      try history.markUndone(trashing.id, at: testDate(3))
    }
    #expect(history == before)
  }

  @Test("a Replace cannot be undone while the replaced document has moved on from the Trash")
  func undoReplaceRefusedWhenReplacedDocumentMovedOn() throws {
    var history = FilingHistory()
    history.recordMove(moveRecord(from: "/Inbox/a.pdf", to: "/Archiv/x.pdf"), at: testDate(1))
    let filingB = history.recordMove(replacingMove(from: "/Inbox/b.pdf"), at: testDate(2))
    let trashing = try #require(history.events.first { $0.causedBy == filingB.id })
    let rescue = history.recordMove(
      moveRecord(from: "/Trash/x.pdf", to: "/Archiv/y.pdf"), at: testDate(3))

    #expect(rescue.documentID == trashing.documentID)
    #expect(
      history.undoBlocker(for: filingB.id)
        == .laterEventActive(trashing.id, later: rescue.id, undoFirst: rescue.id))
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

    #expect(
      throws: FilingHistoryError.laterEventActive(first.id, later: second.id, undoFirst: second.id)
    ) {
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

  // MARK: - Undo checks

  @Test("the undo check passes the latest active event and reports why others cannot be undone")
  func undoBlockerReportsRules() throws {
    var history = FilingHistory()
    let first = history.recordMove(
      moveRecord(from: "/Inbox/scan.pdf", to: "/Archiv/a.pdf"), at: testDate(1))
    let second = history.recordMove(
      moveRecord(from: "/Archiv/a.pdf", to: "/Archiv/b.pdf"), at: testDate(2))
    let other = history.recordMove(
      moveRecord(from: "/Inbox/other.pdf", to: "/Archiv/c.pdf"), at: testDate(3))
    try history.markUndone(other.id, at: testDate(4))
    let before = history
    let unknown = UUID()

    #expect(history.undoBlocker(for: second.id) == nil)
    #expect(
      history.undoBlocker(for: first.id)
        == .laterEventActive(first.id, later: second.id, undoFirst: second.id))
    #expect(history.undoBlocker(for: other.id) == .alreadyUndone(other.id, undoneDate: testDate(4)))
    #expect(history.undoBlocker(for: unknown) == .unknownEvent(unknown))
    #expect(history == before)
  }

  @Test(
    "an event cannot be undone while another document is at its result, and the history is kept")
  func undoRefusesWhenOtherDocumentIsAtResult() throws {
    var history = FilingHistory()
    let filingA = history.recordMove(
      moveRecord(from: "/Inbox/a.pdf", to: "/Archiv/x.pdf"), at: testDate(1))
    // The file was removed outside the app, and another one filed under the same name.
    let filingB = history.recordMove(
      moveRecord(from: "/Inbox/b.pdf", to: "/Archiv/x.pdf"), at: testDate(2))
    let before = history
    let expected = FilingHistoryError.resultHeldByOtherDocument(
      filingA.id, document: filingB.documentID)

    #expect(history.undoBlocker(for: filingA.id) == expected)
    #expect(throws: expected) {
      try history.recordUndo(
        of: filingA.id,
        restoredTo: RestoredItem(url: location("/Inbox/a.pdf"), identity: testIdentity),
        at: testDate(3))
    }
    #expect(history == before)
    #expect(history.undoBlocker(for: filingB.id) == nil)
  }

  @Test("a blocked undo names the event to undo first, following a Replace and later moves")
  func blockerNamesEventToUndoFirst() throws {
    var history = FilingHistory()
    let filingA = history.recordMove(
      moveRecord(from: "/Inbox/a.pdf", to: "/Archiv/x.pdf"), at: testDate(1))
    let filingB = history.recordMove(replacingMove(from: "/Inbox/b.pdf"), at: testDate(2))
    let trashing = try #require(history.events.first { $0.causedBy == filingB.id })
    let renamingB = history.recordMove(
      moveRecord(from: "/Archiv/x.pdf", to: "/Archiv/b.pdf"), at: testDate(3))

    #expect(renamingB.documentID == filingB.documentID)
    #expect(
      history.undoBlocker(for: filingA.id)
        == .laterEventActive(filingA.id, later: trashing.id, undoFirst: renamingB.id))
    #expect(
      history.undoBlocker(for: trashing.id)
        == .undoneWithMove(trashing.id, move: filingB.id, undoFirst: renamingB.id))
    #expect(history.undoBlocker(for: renamingB.id) == nil)
  }

  @Test("after a Replace took a filed document's place, undoing that filing is refused")
  func undoRefusesFilingReplacedLater() throws {
    var history = FilingHistory()
    let filingA = history.recordMove(
      moveRecord(from: "/Inbox/a.pdf", to: "/Archiv/x.pdf"), at: testDate(1))
    let filingB = history.recordMove(replacingMove(from: "/Inbox/b.pdf"), at: testDate(2))
    let trashing = try #require(history.events.first { $0.causedBy == filingB.id })
    let before = history

    #expect(
      history.undoBlocker(for: filingA.id)
        == .laterEventActive(filingA.id, later: trashing.id, undoFirst: filingB.id))
    #expect(throws: FilingHistoryError.self) {
      try history.markUndone(filingA.id, at: testDate(3))
    }
    #expect(history == before)
  }
}
