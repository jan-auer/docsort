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

    #expect(restored.url == source)
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

    #expect(restored.url == fixture.inbox.appending(path: "scan 2.pdf"))
    #expect(try fixture.contents(of: restored.url) == "moved")
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

    #expect(try fixture.operations.undo(record, resolution: .refuse).url == source)
    #expect(try fixture.contents(of: source) == "scan")
  }

  @Test("undoes a case-only rename in place")
  func undoCaseOnlyRename() throws {
    let fixture = try FileOperationsFixture()
    let source = try fixture.directory.createFile("Archiv/rechnung.pdf")
    let record = try fixture.operations.move(
      source, into: fixture.archive, named: "Rechnung.pdf", resolution: .refuse)

    #expect(try fixture.operations.undo(record, resolution: .refuse).url == source)
    #expect(try fixture.names(in: fixture.archive) == ["rechnung.pdf"])
  }

  @Test("undoing a Replace also puts the replaced file back")
  func undoReplace() throws {
    let fixture = try FileOperationsFixture()
    let source = try fixture.directory.createFile("Inbox/scan.pdf", contents: "new")
    let existing = try fixture.directory.createFile("Archiv/rechnung.pdf", contents: "old")
    let record = try fixture.operations.move(
      source, into: fixture.archive, named: "Rechnung.pdf", resolution: .replace)

    #expect(try fixture.operations.undo(record, resolution: .refuse).url == source)

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

@Suite("FileOperations undo identity checks")
struct UndoIdentityTests {
  @Test(
    "a move records the identity of the item at its destination",
    arguments: [RenamingKind.sameVolume, .crossVolume])
  func recordsMovedItem(kind: RenamingKind) throws {
    let fixture = try FileOperationsFixture(renaming: kind.renaming)
    let source = try fixture.directory.createFile("Inbox/scan.pdf", contents: "invoice")

    let record = try fixture.operations.move(
      source, into: fixture.archive, named: "Rechnung.pdf", resolution: .refuse)

    #expect(record.movedItem == (try fixture.identity(of: record.destinationURL)))
  }

  @Test("a cross-volume move records the copy's identity, not the original's")
  func crossVolumeRecordsCopy() throws {
    let fixture = try FileOperationsFixture(renaming: CrossVolumeRenaming())
    let source = try fixture.directory.createFile("Inbox/scan.pdf", contents: "invoice")
    let originalIdentity = try fixture.identity(of: source)

    let record = try fixture.operations.move(
      source, into: fixture.archive, named: "Rechnung.pdf", resolution: .refuse)

    #expect(record.movedItem != originalIdentity)
  }

  @Test("nothing blocks undoing a move whose file is still where it was moved")
  func noBlocker() throws {
    let fixture = try FileOperationsFixture()
    let source = try fixture.directory.createFile("Inbox/scan.pdf")
    let record = try fixture.operations.move(
      source, into: fixture.archive, named: "a.pdf", resolution: .refuse)

    #expect(fixture.operations.undoBlocker(for: record) == nil)
  }

  @Test("refuses to undo a move whose file was swapped for another one, changing nothing")
  func refusesSwappedFile() throws {
    let fixture = try FileOperationsFixture()
    let source = try fixture.directory.createFile("Inbox/scan.pdf", contents: "filed")
    let record = try fixture.operations.move(
      source, into: fixture.archive, named: "Rechnung.pdf", resolution: .refuse)
    try fixture.swapFile(at: record.destinationURL, contents: "swapped in by Finder")

    #expect(
      fixture.operations.undoBlocker(for: record) == .differentItem(at: record.destinationURL))
    #expect(throws: FileOperationError.differentItem(at: record.destinationURL)) {
      try fixture.operations.undo(record, resolution: .refuse)
    }
    #expect(try fixture.contents(of: record.destinationURL) == "swapped in by Finder")
    #expect(try fixture.names(in: fixture.inbox) == [])
  }

  @Test("reports a missing file as the blocker")
  func missingFileBlocks() throws {
    let fixture = try FileOperationsFixture()
    let source = try fixture.directory.createFile("Inbox/scan.pdf")
    let record = try fixture.operations.move(
      source, into: fixture.archive, named: "a.pdf", resolution: .refuse)
    try FileManager.default.removeItem(at: record.destinationURL)

    #expect(fixture.operations.undoBlocker(for: record) == .sourceMissing(record.destinationURL))
  }

  @Test("refuses to undo a Replace whose replaced item in the Trash was swapped, changing nothing")
  func refusesSwappedReplacedItem() throws {
    let fixture = try FileOperationsFixture()
    let source = try fixture.directory.createFile("Inbox/scan.pdf", contents: "new")
    try fixture.directory.createFile("Archiv/Rechnung.pdf", contents: "old")
    let record = try fixture.operations.move(
      source, into: fixture.archive, named: "Rechnung.pdf", resolution: .replace)
    let replaced = try #require(record.replaced)
    try fixture.swapFile(at: replaced.trashedURL, contents: "something else")

    #expect(fixture.operations.undoBlocker(for: record) == .differentItem(at: replaced.trashedURL))
    #expect(throws: FileOperationError.differentItem(at: replaced.trashedURL)) {
      try fixture.operations.undo(record, resolution: .refuse)
    }
    #expect(try fixture.contents(of: record.destinationURL) == "new")
    #expect(!fixture.exists(source))
  }

  @Test("undoing a filing after a Replace took its place is refused; undoing in order works")
  func replaceThenUndoEarlierFiling() throws {
    let fixture = try FileOperationsFixture()
    let fileA = try fixture.directory.createFile("Inbox/a.pdf", contents: "A")
    let fileB = try fixture.directory.createFile("Inbox/b.pdf", contents: "B")
    let target = fixture.archive.appending(path: "x.pdf")
    let filingA = try fixture.operations.move(
      fileA, into: fixture.archive, named: "x.pdf", resolution: .refuse)
    let filingB = try fixture.operations.move(
      fileB, into: fixture.archive, named: "x.pdf", resolution: .replace)

    #expect(throws: FileOperationError.differentItem(at: target)) {
      try fixture.operations.undo(filingA, resolution: .refuse)
    }
    #expect(try fixture.contents(of: target) == "B")
    #expect(try fixture.names(in: fixture.inbox) == [])

    #expect(try fixture.operations.undo(filingB, resolution: .refuse).url == fileB)
    #expect(try fixture.contents(of: target) == "A")
    #expect(try fixture.operations.undo(filingA, resolution: .refuse).url == fileA)
    #expect(try fixture.contents(of: fileA) == "A")
    #expect(try fixture.contents(of: fileB) == "B")
    #expect(try fixture.names(in: fixture.archive) == [])
  }

  @Test(
    "undo returns the identity of the item where it put it back",
    arguments: [RenamingKind.sameVolume, .crossVolume])
  func undoReturnsIdentity(kind: RenamingKind) throws {
    let fixture = try FileOperationsFixture(renaming: kind.renaming)
    let source = try fixture.directory.createFile("Inbox/scan.pdf")
    let record = try fixture.operations.move(
      source, into: fixture.archive, named: "a.pdf", resolution: .refuse)

    let restored = try fixture.operations.undo(record, resolution: .refuse)

    #expect(restored.identity == (try fixture.identity(of: source)))
  }
}
