import Foundation
import Testing

@testable import DocsortCore

@Suite("FileOperations.moveToTrash")
struct TrashTests {
  @Test("moves a file to the Trash and puts it back")
  func trashAndPutBack() throws {
    let fixture = try FileOperationsFixture()
    let file = try fixture.directory.createFile("Inbox/scan.pdf", contents: "scan")

    let record = try fixture.operations.moveToTrash(file)

    #expect(record.originalURL == file)
    #expect(!fixture.exists(file))
    #expect(try fixture.contents(of: record.trashedURL) == "scan")

    let restored = try fixture.operations.undo(record)

    #expect(restored == file)
    #expect(try fixture.contents(of: file) == "scan")
    #expect(try fixture.names(in: fixture.trashFolder) == [])
  }

  @Test("reports a missing item")
  func trashMissing() throws {
    let fixture = try FileOperationsFixture()
    let file = fixture.inbox.appending(path: "gone.pdf")

    #expect(throws: FileOperationError.sourceMissing(file)) {
      try fixture.operations.moveToTrash(file)
    }
  }

  @Test("putting back reports an item that left the Trash")
  func putBackNotInTrash() throws {
    let fixture = try FileOperationsFixture()
    let file = try fixture.directory.createFile("Inbox/scan.pdf")
    let record = try fixture.operations.moveToTrash(file)
    try FileManager.default.removeItem(at: record.trashedURL)

    #expect(throws: FileOperationError.notInTrash(record.trashedURL)) {
      try fixture.operations.undo(record)
    }
  }

  @Test("putting back refuses when the original place is taken")
  func putBackTaken() throws {
    let fixture = try FileOperationsFixture()
    let file = try fixture.directory.createFile("Inbox/scan.pdf", contents: "old")
    let record = try fixture.operations.moveToTrash(file)
    try fixture.directory.createFile("Inbox/Scan.pdf", contents: "new")

    #expect(throws: FileOperationError.originalLocationTaken(file)) {
      try fixture.operations.undo(record)
    }
    #expect(try fixture.contents(of: record.trashedURL) == "old")
  }

  @Test("putting back recreates the original folder")
  func putBackRecreatesFolder() throws {
    let fixture = try FileOperationsFixture()
    let file = try fixture.directory.createFile("Inbox/Unterordner/scan.pdf", contents: "scan")
    let record = try fixture.operations.moveToTrash(file)
    try FileManager.default.removeItem(at: fixture.inbox.appending(path: "Unterordner"))

    #expect(try fixture.operations.undo(record) == file)
    #expect(try fixture.contents(of: file) == "scan")
  }

  @Test("the system Trash takes a file and gives it back, leaving the Trash as it was")
  func systemTrashRoundTrip() throws {
    let directory = try TemporaryDirectory()
    let file = try directory.createFile(
      "docsort-trash-test-\(UUID().uuidString).txt", contents: "x")
    let operations = FileOperations(trash: SystemTrash())

    let record = try operations.moveToTrash(file)
    #expect(record.trashedURL != file)
    #expect(FileManager.default.fileExists(atPath: record.trashedURL.path(percentEncoded: false)))

    #expect(try operations.undo(record) == file)
    #expect(FileManager.default.fileExists(atPath: file.path(percentEncoded: false)))
    #expect(!FileManager.default.fileExists(atPath: record.trashedURL.path(percentEncoded: false)))
  }
}
