import Foundation
import Testing

@testable import DocsortCore

@Suite("FileOperations.undo(MoveRecord)")
struct UndoMoveTests {
  @Test("puts the file back under its original name and removes the folders the move created")
  func undoRestoresAndRemovesFolders() throws {
    let fixture = try FileOperationsFixture()
    let source = try fixture.directory.createFile("Inbox/scan.pdf", contents: "invoice")
    let target = fixture.archive.appending(
      path: "2026-11 Monitor/Lieferschein", directoryHint: .isDirectory)
    let record = try fixture.operations.move(
      source, into: target, named: "Lieferschein.pdf", resolution: .refuse)

    let restored = try fixture.operations.undo(record, resolution: .refuse)

    #expect(restored == source)
    #expect(try fixture.contents(of: source) == "invoice")
    #expect(try fixture.names(in: fixture.archive) == [])
  }

  @Test("keeps created folders that are no longer empty, and removes those holding only .DS_Store")
  func undoKeepsNonEmptyFolders() throws {
    let fixture = try FileOperationsFixture()
    let source = try fixture.directory.createFile("Inbox/scan.pdf")
    let target = fixture.archive.appending(
      path: "2026-11 Monitor/Lieferschein", directoryHint: .isDirectory)
    let record = try fixture.operations.move(
      source, into: target, named: "scan.pdf", resolution: .refuse)
    try fixture.directory.createFile("Archiv/2026-11 Monitor/Rechnung.pdf")
    try fixture.directory.createFile("Archiv/2026-11 Monitor/Lieferschein/.DS_Store")

    _ = try fixture.operations.undo(record, resolution: .refuse)

    #expect(
      try fixture.names(in: fixture.archive.appending(path: "2026-11 Monitor")) == ["Rechnung.pdf"])
  }

  @Test("refuses when the original place is taken and changes nothing")
  func undoRefusesTakenOriginal() throws {
    let fixture = try FileOperationsFixture()
    let source = try fixture.directory.createFile("Inbox/scan.pdf", contents: "moved")
    let record = try fixture.operations.move(
      source, into: fixture.archive, named: "a.pdf", resolution: .refuse)
    try fixture.directory.createFile("Inbox/SCAN.pdf", contents: "newcomer")

    #expect(throws: FileOperationError.originalLocationTaken(source)) {
      try fixture.operations.undo(record, resolution: .refuse)
    }
    #expect(try fixture.contents(of: record.destinationURL) == "moved")
    #expect(try fixture.names(in: fixture.inbox) == ["SCAN.pdf"])
  }

  @Test("Keep Both puts the file back under a numbered name when the original place is taken")
  func undoKeepBoth() throws {
    let fixture = try FileOperationsFixture()
    let source = try fixture.directory.createFile("Inbox/scan.pdf", contents: "moved")
    let record = try fixture.operations.move(
      source, into: fixture.archive, named: "a.pdf", resolution: .refuse)
    try fixture.directory.createFile("Inbox/scan.pdf", contents: "newcomer")

    let restored = try fixture.operations.undo(record, resolution: .keepBoth)

    #expect(restored == fixture.inbox.appending(path: "scan 2.pdf"))
    #expect(try fixture.contents(of: restored) == "moved")
    #expect(try fixture.contents(of: source) == "newcomer")
  }

  @Test("reports a moved file that vanished from its destination")
  func undoMovedFileGone() throws {
    let fixture = try FileOperationsFixture()
    let source = try fixture.directory.createFile("Inbox/scan.pdf")
    let record = try fixture.operations.move(
      source, into: fixture.archive, named: "a.pdf", resolution: .refuse)
    try FileManager.default.removeItem(at: record.destinationURL)

    #expect(throws: FileOperationError.sourceMissing(record.destinationURL)) {
      try fixture.operations.undo(record, resolution: .refuse)
    }
  }

  @Test("recreates the original folder when it was removed")
  func undoRecreatesOriginalFolder() throws {
    let fixture = try FileOperationsFixture()
    let source = try fixture.directory.createFile("Inbox/Downloads/scan.pdf", contents: "scan")
    let record = try fixture.operations.move(
      source, into: fixture.archive, named: "a.pdf", resolution: .refuse)
    try FileManager.default.removeItem(at: fixture.inbox.appending(path: "Downloads"))

    #expect(try fixture.operations.undo(record, resolution: .refuse) == source)
    #expect(try fixture.contents(of: source) == "scan")
  }

  @Test("undoes a case-only rename in place")
  func undoCaseOnlyRename() throws {
    let fixture = try FileOperationsFixture()
    let source = try fixture.directory.createFile("Archiv/rechnung.pdf")
    let record = try fixture.operations.move(
      source, into: fixture.archive, named: "Rechnung.pdf", resolution: .refuse)

    #expect(try fixture.operations.undo(record, resolution: .refuse) == source)
    #expect(try fixture.names(in: fixture.archive) == ["rechnung.pdf"])
  }

  @Test("undoing a Replace also puts the replaced file back")
  func undoReplace() throws {
    let fixture = try FileOperationsFixture()
    let source = try fixture.directory.createFile("Inbox/scan.pdf", contents: "new")
    let existing = try fixture.directory.createFile("Archiv/rechnung.pdf", contents: "old")
    let record = try fixture.operations.move(
      source, into: fixture.archive, named: "Rechnung.pdf", resolution: .replace)

    #expect(try fixture.operations.undo(record, resolution: .refuse) == source)

    #expect(try fixture.contents(of: source) == "new")
    #expect(try fixture.contents(of: existing) == "old")
    #expect(try fixture.names(in: fixture.archive) == ["rechnung.pdf"])
    #expect(try fixture.names(in: fixture.trashFolder) == [])
  }

  @Test("undoing a Replace whose replaced file left the Trash changes nothing")
  func undoReplaceNotInTrash() throws {
    let fixture = try FileOperationsFixture()
    let source = try fixture.directory.createFile("Inbox/scan.pdf", contents: "new")
    try fixture.directory.createFile("Archiv/Rechnung.pdf", contents: "old")
    let record = try fixture.operations.move(
      source, into: fixture.archive, named: "Rechnung.pdf", resolution: .replace)
    let replaced = try #require(record.replaced)
    try FileManager.default.removeItem(at: replaced.trashedURL)

    #expect(throws: FileOperationError.notInTrash(replaced.trashedURL)) {
      try fixture.operations.undo(record, resolution: .refuse)
    }
    #expect(try fixture.contents(of: record.destinationURL) == "new")
    #expect(!fixture.exists(source))
  }
}
