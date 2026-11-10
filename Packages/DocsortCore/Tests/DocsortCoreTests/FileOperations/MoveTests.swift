import Foundation
import Testing

@testable import DocsortCore

@Suite("FileOperations.move")
struct MoveTests {
  @Test("moves the file under the new name and records it")
  func movesFile() throws {
    let fixture = try FileOperationsFixture()
    let source = try fixture.directory.createFile("Inbox/scan.pdf", contents: "invoice")
    let folder = try fixture.directory.createFolder("Archiv/Rechnungen")

    let record = try fixture.operations.move(
      source, into: folder, named: "Rechnung.pdf", resolution: .refuse)

    let destination = folder.appending(path: "Rechnung.pdf")
    #expect(record.originalURL == source)
    #expect(record.destinationURL == destination)
    #expect(record.createdFolders == [])
    #expect(record.replaced == nil)
    #expect(record.movedItem == (try fixture.identity(of: destination)))
    #expect(try fixture.contents(of: destination) == "invoice")
    #expect(!fixture.exists(source))
  }

  @Test("creates missing nested folders and records them outermost first")
  func createsMissingFolders() throws {
    let fixture = try FileOperationsFixture()
    let source = try fixture.directory.createFile("Inbox/scan.pdf")
    let monitor = fixture.archive.appending(path: "2033-11 Monitor", directoryHint: .isDirectory)
    let deliveryNotes = monitor.appending(path: "Lieferschein", directoryHint: .isDirectory)

    let record = try fixture.operations.move(
      source, into: deliveryNotes, named: "scan.pdf", resolution: .refuse)

    #expect(record.createdFolders.map(\.lastPathComponent) == ["2033-11 Monitor", "Lieferschein"])
    #expect(
      record.createdFolders.map(\.standardizedFileURL)
        == [monitor, deliveryNotes].map(\.standardizedFileURL))
    #expect(fixture.exists(deliveryNotes.appending(path: "scan.pdf")))
  }

  @Test("records only the folders it created, using an existing one spelt in another case")
  func reusesExistingFolders() throws {
    let fixture = try FileOperationsFixture()
    let source = try fixture.directory.createFile("Inbox/scan.pdf")
    try fixture.directory.createFolder("Archiv/2033-11 Monitor")
    let deliveryNotes = fixture.archive.appending(
      path: "2033-11 monitor/Lieferschein", directoryHint: .isDirectory)

    let record = try fixture.operations.move(
      source, into: deliveryNotes, named: "scan.pdf", resolution: .refuse)

    #expect(record.createdFolders.map(\.lastPathComponent) == ["Lieferschein"])
    #expect(try fixture.names(in: fixture.archive) == ["2033-11 Monitor"])
  }

  @Test("fails when a file stands where a folder should be, changing nothing")
  func fileInTheWay() throws {
    let fixture = try FileOperationsFixture()
    let source = try fixture.directory.createFile("Inbox/scan.pdf")
    try fixture.directory.createFile("Archiv/a")

    #expect(throws: FileOperationError.self) {
      try fixture.operations.move(
        source, into: fixture.archive.appending(path: "a/b", directoryHint: .isDirectory),
        named: "scan.pdf", resolution: .refuse)
    }
    #expect(try fixture.names(in: fixture.archive) == ["a"])
    #expect(fixture.exists(source))
  }

  @Test("refuses a taken name and changes nothing")
  func refusesConflict() throws {
    let fixture = try FileOperationsFixture()
    let source = try fixture.directory.createFile("Inbox/scan.pdf", contents: "new")
    let existing = try fixture.directory.createFile("Archiv/Rechnung.pdf", contents: "old")

    #expect(throws: FileOperationError.nameConflict(existing: existing)) {
      try fixture.operations.move(
        source, into: fixture.archive, named: "Rechnung.pdf", resolution: .refuse)
    }
    #expect(try fixture.contents(of: source) == "new")
    #expect(try fixture.contents(of: existing) == "old")
    #expect(try fixture.names(in: fixture.archive) == ["Rechnung.pdf"])
  }

  @Test("names differing only in case conflict")
  func caseOnlyConflict() throws {
    let fixture = try FileOperationsFixture()
    let source = try fixture.directory.createFile("Inbox/scan.pdf")
    let existing = try fixture.directory.createFile("Archiv/rechnung.pdf")

    #expect(throws: FileOperationError.nameConflict(existing: existing)) {
      try fixture.operations.move(
        source, into: fixture.archive, named: "Rechnung.pdf", resolution: .refuse)
    }
    #expect(fixture.exists(source))
  }

  @Test("a decomposed name on disk conflicts with the precomposed name in another case")
  func unicodeNormalisationConflict() throws {
    let fixture = try FileOperationsFixture()
    let source = try fixture.directory.createFile("Inbox/scan.pdf")
    let decomposedName = "Ku\u{0308}ndigung.pdf"
    let existing = try fixture.directory.createFile("Archiv/\(decomposedName)")

    #expect(
      try fixture.operations.existingItem(named: "k\u{00FC}ndigung.pdf", in: fixture.archive)
        == existing)
    #expect(throws: FileOperationError.nameConflict(existing: existing)) {
      try fixture.operations.move(
        source, into: fixture.archive, named: "k\u{00FC}ndigung.pdf", resolution: .refuse)
    }
  }

  @Test("re-filing into its own folder with only a case change is not a conflict")
  func caseOnlyRenameInPlace() throws {
    let fixture = try FileOperationsFixture()
    let source = try fixture.directory.createFile("Archiv/rechnung.pdf", contents: "invoice")

    let record = try fixture.operations.move(
      source, into: fixture.archive, named: "Rechnung.pdf", resolution: .refuse)

    #expect(record.destinationURL == fixture.archive.appending(path: "Rechnung.pdf"))
    #expect(record.replaced == nil)
    #expect(try fixture.names(in: fixture.archive) == ["Rechnung.pdf"])
    #expect(try fixture.contents(of: record.destinationURL) == "invoice")
  }

  @Test("Keep Both moves under the next free numbered name")
  func keepBoth() throws {
    let fixture = try FileOperationsFixture()
    let source = try fixture.directory.createFile("Inbox/scan.pdf", contents: "new")
    try fixture.directory.createFile("Archiv/Rechnung.pdf", contents: "old")
    try fixture.directory.createFile("Archiv/rechnung 2.pdf", contents: "older")

    let record = try fixture.operations.move(
      source, into: fixture.archive, named: "Rechnung.pdf", resolution: .keepBoth)

    #expect(record.destinationURL == fixture.archive.appending(path: "Rechnung 3.pdf"))
    #expect(try fixture.contents(of: record.destinationURL) == "new")
    #expect(try fixture.contents(of: fixture.archive.appending(path: "Rechnung.pdf")) == "old")
    #expect(record.replaced == nil)
  }

  @Test("Replace sends the existing file to the Trash and records it")
  func replace() throws {
    let fixture = try FileOperationsFixture()
    let source = try fixture.directory.createFile("Inbox/scan.pdf", contents: "new")
    let existing = try fixture.directory.createFile("Archiv/rechnung.pdf", contents: "old")

    let record = try fixture.operations.move(
      source, into: fixture.archive, named: "Rechnung.pdf", resolution: .replace)

    let replaced = try #require(record.replaced)
    #expect(replaced.originalURL == existing)
    #expect(try fixture.contents(of: replaced.trashedURL) == "old")
    #expect(try fixture.names(in: fixture.archive) == ["Rechnung.pdf"])
    #expect(try fixture.contents(of: record.destinationURL) == "new")
  }

  @Test("Replace puts the existing file back when the move fails")
  func replaceRollsBack() throws {
    let directory = try TemporaryDirectory()
    let source = try directory.createFile("Inbox/scan.pdf", contents: "new")
    let archive = try directory.createFolder("Archiv")
    let existing = try directory.createFile("Archiv/Rechnung.pdf", contents: "old")
    let operations = FileOperations(
      trash: FolderTrash(folder: try directory.createFolder("Trash")),
      renaming: FailingRenaming(failingSource: source))

    #expect(throws: FileOperationError.self) {
      try operations.move(source, into: archive, named: "Rechnung.pdf", resolution: .replace)
    }
    #expect(String(decoding: try Data(contentsOf: existing), as: UTF8.self) == "old")
    #expect(FileManager.default.fileExists(atPath: source.path(percentEncoded: false)))
  }

  @Test("Replace refuses to trash a folder to make room for a file, changing nothing")
  func replaceRefusesFolderForFile() throws {
    let fixture = try FileOperationsFixture()
    let source = try fixture.directory.createFile("Inbox/scan.pdf", contents: "new")
    try fixture.directory.createFile("Archiv/Rechnung.pdf/inside.txt", contents: "kept")
    let existing = fixture.archive.appending(path: "Rechnung.pdf")

    #expect(throws: FileOperationError.replaceKindMismatch(existing: existing)) {
      try fixture.operations.move(
        source, into: fixture.archive, named: "Rechnung.pdf", resolution: .replace)
    }
    #expect(try fixture.contents(of: source) == "new")
    #expect(try fixture.contents(of: existing.appending(path: "inside.txt")) == "kept")
    #expect(try fixture.names(in: fixture.trashFolder) == [])
  }

  @Test("Replace refuses to trash a file to make room for a folder or package, changing nothing")
  func replaceRefusesFileForFolder() throws {
    let fixture = try FileOperationsFixture()
    try fixture.directory.createFile("Inbox/Brief.pages/Data/body.xml", contents: "body")
    let source = fixture.inbox.appending(path: "Brief.pages", directoryHint: .isDirectory)
    let existing = try fixture.directory.createFile("Archiv/Brief.pages", contents: "old")

    #expect(throws: FileOperationError.replaceKindMismatch(existing: existing)) {
      try fixture.operations.move(
        source, into: fixture.archive, named: "Brief.pages", resolution: .replace)
    }
    #expect(try fixture.contents(of: source.appending(path: "Data/body.xml")) == "body")
    #expect(try fixture.contents(of: existing) == "old")
    #expect(try fixture.names(in: fixture.trashFolder) == [])
  }

  @Test("reports a missing source")
  func sourceMissing() throws {
    let fixture = try FileOperationsFixture()
    let source = fixture.inbox.appending(path: "gone.pdf")

    #expect(throws: FileOperationError.sourceMissing(source)) {
      try fixture.operations.move(
        source, into: fixture.archive, named: "a.pdf", resolution: .refuse)
    }
  }

  @Test("refuses an invalid name before touching anything")
  func invalidName() throws {
    let fixture = try FileOperationsFixture()
    let source = try fixture.directory.createFile("Inbox/scan.pdf")
    let newFolder = fixture.archive.appending(path: "Neu", directoryHint: .isDirectory)

    #expect(throws: FileOperationError.invalidName("a:b.pdf", .forbiddenCharacter(":"))) {
      try fixture.operations.move(source, into: newFolder, named: "a:b.pdf", resolution: .refuse)
    }
    #expect(!fixture.exists(newFolder))
  }

  @Test("refuses an invalid folder name before creating any folder")
  func invalidFolderName() throws {
    let fixture = try FileOperationsFixture()
    let source = try fixture.directory.createFile("Inbox/scan.pdf")
    let outer = fixture.archive.appending(path: "Neu", directoryHint: .isDirectory)
    let inner = outer.appending(path: "a:b", directoryHint: .isDirectory)

    #expect(throws: FileOperationError.invalidName("a:b", .forbiddenCharacter(":"))) {
      try fixture.operations.move(source, into: inner, named: "scan.pdf", resolution: .refuse)
    }
    #expect(!fixture.exists(outer))
    #expect(fixture.exists(source))
  }

  @Test(
    "the rename primitive itself never replaces an item that appeared after the name check",
    arguments: [RenamingKind.sameVolume, .crossVolume])
  func relocateNeverOverwrites(kind: RenamingKind) throws {
    let fixture = try FileOperationsFixture(renaming: kind.renaming)
    let source = try fixture.directory.createFile("Inbox/scan.pdf", contents: "new")
    let existing = try fixture.directory.createFile("Archiv/Rechnung.pdf", contents: "old")

    #expect(throws: FileOperationError.nameConflict(existing: existing)) {
      try fixture.operations.relocate(source, to: existing)
    }
    #expect(try fixture.contents(of: existing) == "old")
    #expect(try fixture.contents(of: source) == "new")
    #expect(try fixture.names(in: fixture.archive) == ["Rechnung.pdf"])
  }

  @Test("moves to another volume by copying, then removing the original")
  func crossVolumeMove() throws {
    let fixture = try FileOperationsFixture(renaming: CrossVolumeRenaming())
    let source = try fixture.directory.createFile("Inbox/scan.pdf", contents: "invoice")

    let record = try fixture.operations.move(
      source, into: fixture.archive, named: "Rechnung.pdf", resolution: .refuse)

    #expect(try fixture.contents(of: record.destinationURL) == "invoice")
    #expect(!fixture.exists(source))
    #expect(try fixture.names(in: fixture.archive) == ["Rechnung.pdf"])
  }

  @Test("moves a folder to another volume with all its contents")
  func crossVolumeFolderMove() throws {
    let fixture = try FileOperationsFixture(renaming: CrossVolumeRenaming())
    try fixture.directory.createFile("Inbox/Bundle.pages/Data/body.xml", contents: "body")
    let source = fixture.inbox.appending(path: "Bundle.pages", directoryHint: .isDirectory)

    let record = try fixture.operations.move(
      source, into: fixture.archive, named: "Brief.pages", resolution: .refuse)

    #expect(
      try fixture.contents(of: record.destinationURL.appending(path: "Data/body.xml")) == "body")
    #expect(!fixture.exists(source))
    #expect(try fixture.names(in: fixture.archive) == ["Brief.pages"])
  }

  @Test("a cross-volume move whose original cannot be removed removes the copy again")
  func crossVolumeRollback() throws {
    let fixture = try FileOperationsFixture(renaming: CrossVolumeRenaming())
    let source = try fixture.directory.createFile("Inbox/scan.pdf", contents: "invoice")
    let inboxPath = fixture.inbox.path(percentEncoded: false)
    try FileManager.default.setAttributes([.posixPermissions: 0o555], ofItemAtPath: inboxPath)
    defer {
      // Restore write access so the temporary directory can be removed; a failure here only leaks a temp folder.
      try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: inboxPath)
    }

    let error = #expect(throws: FileOperationError.self) {
      try fixture.operations.move(
        source, into: fixture.archive, named: "Rechnung.pdf", resolution: .refuse)
    }
    guard case .failed(_, let url, _) = error else {
      Issue.record("expected a failed error, got \(String(describing: error))")
      return
    }
    #expect(url == source)
    #expect(try fixture.contents(of: source) == "invoice")
    #expect(try fixture.names(in: fixture.archive) == [])
  }
}

@Suite("FileOperations.move across volumes while the original changes")
struct CrossVolumeChangeTests {
  @Test("keeps both when the original is rewritten during the copy")
  func originalRewritten() throws {
    let fixture = try FileOperationsFixture(renaming: CrossVolumeRenaming()) { original in
      #expect(throws: Never.self) { try Data("a newer version".utf8).write(to: original) }
    }
    let source = try fixture.directory.createFile("Inbox/scan.pdf", contents: "invoice")
    let destination = fixture.archive.appending(path: "Rechnung.pdf")

    #expect(
      throws: FileOperationError.originalChangedDuringCopy(
        original: source, copy: destination, replaced: nil)
    ) {
      try fixture.operations.move(
        source, into: fixture.archive, named: "Rechnung.pdf", resolution: .refuse)
    }
    #expect(try fixture.contents(of: source) == "a newer version")
    #expect(try fixture.contents(of: destination) == "invoice")
  }

  @Test("keeps both when the original is swapped for a file of the same size and date")
  func originalSwapped() throws {
    let fixture = try FileOperationsFixture(renaming: CrossVolumeRenaming()) { original in
      #expect(throws: Never.self) {
        let modified = try #require(
          try FileManager.default.attributesOfItem(atPath: original.path)[.modificationDate]
            as? Date)
        let replacement = original.deletingLastPathComponent().appending(path: "replacement")
        try Data("INVOICE".utf8).write(to: replacement)
        try FileManager.default.setAttributes(
          [.modificationDate: modified], ofItemAtPath: replacement.path)
        try FileManager.default.removeItem(at: original)
        try FileManager.default.moveItem(at: replacement, to: original)
      }
    }
    let source = try fixture.directory.createFile(
      "Inbox/scan.pdf", contents: "invoice", modified: testDate(1))
    let destination = fixture.archive.appending(path: "Rechnung.pdf")

    #expect(
      throws: FileOperationError.originalChangedDuringCopy(
        original: source, copy: destination, replaced: nil)
    ) {
      try fixture.operations.move(
        source, into: fixture.archive, named: "Rechnung.pdf", resolution: .refuse)
    }
    #expect(try fixture.contents(of: source) == "INVOICE")
    #expect(try fixture.contents(of: destination) == "invoice")
  }

  @Test("keeps both when a file deep inside the original folder changes during the copy")
  func folderContentChanged() throws {
    let fixture = try FileOperationsFixture(renaming: CrossVolumeRenaming()) { original in
      #expect(throws: Never.self) {
        try Data("edited body".utf8).write(to: original.appending(path: "Data/body.xml"))
      }
    }
    try fixture.directory.createFile("Inbox/Bundle.pages/Data/body.xml", contents: "body")
    let source = fixture.inbox.appending(path: "Bundle.pages", directoryHint: .isDirectory)

    let error = #expect(throws: FileOperationError.self) {
      try fixture.operations.move(
        source, into: fixture.archive, named: "Brief.pages", resolution: .refuse)
    }

    guard case .originalChangedDuringCopy(let original, let copy, nil) = error else {
      Issue.record("expected originalChangedDuringCopy, got \(String(describing: error))")
      return
    }
    #expect(original == source)
    #expect(try fixture.contents(of: source.appending(path: "Data/body.xml")) == "edited body")
    #expect(try fixture.contents(of: copy.appending(path: "Data/body.xml")) == "body")
  }

  @Test("after a Replace, the replaced item stays in the Trash and the error carries its record")
  func replacedItemStaysInTrash() throws {
    let fixture = try FileOperationsFixture(renaming: CrossVolumeRenaming()) { original in
      #expect(throws: Never.self) { try Data("a newer version".utf8).write(to: original) }
    }
    let source = try fixture.directory.createFile("Inbox/scan.pdf", contents: "invoice")
    let existing = try fixture.directory.createFile("Archiv/Rechnung.pdf", contents: "old")

    let error = #expect(throws: FileOperationError.self) {
      try fixture.operations.move(
        source, into: fixture.archive, named: "Rechnung.pdf", resolution: .replace)
    }

    guard case .originalChangedDuringCopy(_, let copy, let replaced?) = error else {
      Issue.record(
        "expected originalChangedDuringCopy with a replaced item, got \(String(describing: error))")
      return
    }
    #expect(replaced.originalURL == existing)
    #expect(try fixture.contents(of: replaced.trashedURL) == "old")
    #expect(try fixture.contents(of: copy) == "invoice")
    #expect(try fixture.contents(of: source) == "a newer version")
  }
}
