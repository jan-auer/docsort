import DocsortCore
import Foundation
import Testing

@testable import Docsort

@MainActor
@Suite("MainWindowModel: renaming and trashing archive files")
struct MainWindowModelArchiveFileTests {
  private let notenPath = "Musik Margit/Noten & Bücher"

  private func exists(_ url: URL) -> Bool {
    FileManager.default.fileExists(atPath: url.path(percentEncoded: false))
  }

  /// The archive file at `url`, as Folder contents lists it.
  private func folderFile(at url: URL) -> FolderFile {
    FolderFile(url: url, name: url.lastPathComponent)
  }

  @Test("Rename… renames an archive file in its folder; undo restores its name")
  func renameAndUndo() async throws {
    let environment = try TestFolderEnvironment()
    defer { environment.remove() }
    let folder = environment.archive.appending(path: notenPath)
    let sheet = try writeInboxFile(
      named: "2033-10-13 Notenhaus.pdf", in: folder, date: october2033(2))
    let (model, undoManager) = try await TestWindow.open(on: environment)
    let renamed = folder.appending(path: "2033-10-13 Notenhaus Allegretto.pdf")

    // The name is entered without its extension, as in the name field.
    model.handlePickerEvent(
      .renameFileRequested(folderFile(at: sheet), to: "2033-10-13 Notenhaus Allegretto"))
    // The file is renamed on disk before the model registers the undo.
    try await waitUntil { undoManager.canUndo }
    #expect(exists(renamed))
    #expect(!exists(sheet))
    #expect(undoManager.undoActionName.contains("2033-10-13 Notenhaus.pdf"))
    #expect(model.statusMessage?.text.contains("2033-10-13 Notenhaus Allegretto.pdf") == true)

    undoManager.undo()
    try await waitUntil { exists(sheet) }
    #expect(!exists(renamed))
  }

  @Test("A name macOS forbids is refused before anything is renamed")
  func renameRefusesForbiddenName() async throws {
    let environment = try TestFolderEnvironment()
    defer { environment.remove() }
    let folder = environment.archive.appending(path: notenPath)
    let sheet = try writeInboxFile(
      named: "2033-10-13 Notenhaus.pdf", in: folder, date: october2033(2))
    let (model, undoManager) = try await TestWindow.open(on: environment)

    model.handlePickerEvent(
      .renameFileRequested(folderFile(at: sheet), to: "Notenhaus: Allegretto"))
    #expect(model.alert != nil)
    #expect(exists(sheet))
    #expect(!undoManager.canUndo)
  }

  @Test("Renaming a filed file in the archive updates its row; undo restores the row's mark")
  func renameFiledFileFollowsRow() async throws {
    let environment = try TestFolderEnvironment()
    defer { environment.remove() }
    let invoice = try writeInboxFile(
      named: "Rechnung_NA-33-08812.pdf", in: environment.webDownloads, date: october2033(13))
    let (model, undoManager) = try await TestWindow.open(on: environment)
    let row = try #require(model.inboxes.orderedRows.first)
    let filed = try await model.filing.file(
      invoice, into: environment.archive.appending(path: notenPath), archivePath: notenPath,
      named: "2033-10-13 Notenhaus Allegretto.pdf", resolution: .refuse)
    let filedMark = InboxItemMark.filed(
      newURL: filed.movedURL, destinationPath: notenPath, date: filed.event.date,
      documentID: filed.event.documentID)
    model.inboxes.setMark(row.id, filedMark)

    model.handlePickerEvent(
      .renameFileRequested(
        folderFile(at: filed.movedURL), to: "2033-10-13 Notenhaus Allegretto Advent"))
    try await waitUntil { model.inboxes.row(for: row.id)?.mark != filedMark }
    guard
      case .filed(let newURL, let destinationPath, _, let documentID)? =
        model.inboxes.row(for: row.id)?.mark
    else {
      Issue.record("The row is no longer filed")
      return
    }
    #expect(newURL.lastPathComponent == "2033-10-13 Notenhaus Allegretto Advent.pdf")
    #expect(destinationPath == notenPath)
    #expect(documentID == filed.event.documentID)

    undoManager.undo()
    try await waitUntil { model.inboxes.row(for: row.id)?.mark == filedMark }
    #expect(exists(filed.movedURL))
  }

  @Test(
    "Move to Trash trashes an archive file and marks a row that filed it trashed; undo restores both"
  )
  func trashFiledFileAndUndo() async throws {
    let environment = try TestFolderEnvironment()
    defer { environment.remove() }
    let invoice = try writeInboxFile(
      named: "Rechnung_NA-33-08812.pdf", in: environment.webDownloads, date: october2033(13))
    let (model, undoManager) = try await TestWindow.open(on: environment)
    let row = try #require(model.inboxes.orderedRows.first)
    let filed = try await model.filing.file(
      invoice, into: environment.archive.appending(path: notenPath), archivePath: notenPath,
      named: "2033-10-13 Notenhaus Allegretto.pdf", resolution: .refuse)
    let filedMark = InboxItemMark.filed(
      newURL: filed.movedURL, destinationPath: notenPath, date: filed.event.date,
      documentID: filed.event.documentID)
    model.inboxes.setMark(row.id, filedMark)

    model.handlePickerEvent(.trashFileRequested(folderFile(at: filed.movedURL)))
    try await waitUntil { undoManager.canUndo }
    #expect(!exists(filed.movedURL))
    try await waitUntil {
      if case .trashed? = model.inboxes.row(for: row.id)?.mark { true } else { false }
    }
    #expect(undoManager.undoActionName.contains("2033-10-13 Notenhaus Allegretto.pdf"))

    undoManager.undo()
    try await waitUntil { model.inboxes.row(for: row.id)?.mark == filedMark }
    #expect(exists(filed.movedURL))
  }

  /// Files the inbox file `invoice` into Noten & Bücher and marks `row` filed, as the filing panel does.
  private func fileInvoice(
    _ invoice: URL, row: InboxItemID, in model: MainWindowModel, environment: TestFolderEnvironment
  ) async throws -> (outcome: MoveOutcome, mark: InboxItemMark) {
    let filed = try await model.filing.file(
      invoice, into: environment.archive.appending(path: notenPath), archivePath: notenPath,
      named: "2033-10-13 Notenhaus Allegretto.pdf", resolution: .refuse)
    let mark = InboxItemMark.filed(
      newURL: filed.movedURL, destinationPath: notenPath, date: filed.event.date,
      documentID: filed.event.documentID)
    model.inboxes.setMark(row, mark)
    return (filed, mark)
  }

  @Test(
    "Put Back of a filed file trashed in Folder contents returns it to its folder, filed; undo and redo follow"
  )
  func putBackArchiveTrashedFile() async throws {
    let environment = try TestFolderEnvironment()
    defer { environment.remove() }
    let invoice = try writeInboxFile(
      named: "Rechnung_NA-33-08812.pdf", in: environment.webDownloads, date: october2033(13))
    let (model, undoManager) = try await TestWindow.open(on: environment)
    let row = try #require(model.inboxes.orderedRows.first)
    let (filed, _) = try await fileInvoice(
      invoice, row: row.id, in: model, environment: environment)
    model.handlePickerEvent(.trashFileRequested(folderFile(at: filed.movedURL)))
    try await waitUntil { undoManager.canUndo }
    undoManager.removeAllActions()
    let trashedFile = try #require(model.file(row.id))
    #expect(trashedFile.returnToInboxAction == .putBack)

    model.returnToInbox(trashedFile)
    try await waitUntil { undoManager.canUndo }

    func isFiledAtArchivePlace() -> Bool {
      guard
        case .filed(let url, let path, _, let documentID)? = model.inboxes.row(for: row.id)?.mark
      else { return false }
      return url.path(percentEncoded: false) == filed.movedURL.path(percentEncoded: false)
        && path == notenPath && documentID == filed.event.documentID
    }
    #expect(isFiledAtArchivePlace())
    #expect(exists(filed.movedURL))
    #expect(!exists(invoice))
    #expect(model.statusMessage?.text.contains("Noten & Bücher") == true)
    #expect(model.statusMessage?.text.contains("Web-Downloads") == false)

    undoManager.undo()
    try await waitUntil {
      if case .trashed? = model.inboxes.row(for: row.id)?.mark { true } else { false }
    }
    #expect(!exists(filed.movedURL))

    undoManager.redo()
    try await waitUntil { isFiledAtArchivePlace() }
    #expect(exists(filed.movedURL))
  }

  @Test(
    "Renaming the selected filed file in Folder contents updates the name field; undo and redo too")
  func renameSelectedFiledFileUpdatesNameField() async throws {
    let environment = try TestFolderEnvironment()
    defer { environment.remove() }
    let invoice = try writeInboxFile(
      named: "Rechnung_NA-33-08812.pdf", in: environment.webDownloads, date: october2033(13))
    let (model, undoManager) = try await TestWindow.open(on: environment)
    let row = try #require(model.inboxes.orderedRows.first)
    let (filed, _) = try await fileInvoice(
      invoice, row: row.id, in: model, environment: environment)
    model.select(row.id)
    model.resetPanel()
    #expect(model.panel.nameText == "2033-10-13 Notenhaus Allegretto")

    model.handlePickerEvent(
      .renameFileRequested(
        folderFile(at: filed.movedURL), to: "2033-10-13 Notenhaus Allegretto Advent"))
    try await waitUntil { undoManager.canUndo }
    #expect(model.panel.nameText == "2033-10-13 Notenhaus Allegretto Advent")
    #expect(model.filedFileChange != .rename)

    undoManager.undo()
    try await waitUntil { model.panel.nameText == "2033-10-13 Notenhaus Allegretto" }

    undoManager.redo()
    try await waitUntil { model.panel.nameText == "2033-10-13 Notenhaus Allegretto Advent" }
  }

  /// The names Folder contents lists; empty unless it lists files.
  private func listedNames(_ model: MainWindowModel) -> [String] {
    model.picker.contentsFiles.map(\.name)
  }

  @Test(
    "Folder contents lists a file put back into its folder, drops it on undo and lists it again on redo"
  )
  func putBackReloadsFolderContents() async throws {
    let environment = try TestFolderEnvironment()
    defer { environment.remove() }
    let invoice = try writeInboxFile(
      named: "Rechnung_NA-33-08812.pdf", in: environment.webDownloads, date: october2033(13))
    let (model, undoManager) = try await TestWindow.open(on: environment)
    let row = try #require(model.inboxes.orderedRows.first)
    let (filed, _) = try await fileInvoice(
      invoice, row: row.id, in: model, environment: environment)
    model.select(row.id)
    model.resetPanel()
    try await waitUntil { listedNames(model) == ["2033-10-13 Notenhaus Allegretto.pdf"] }
    model.handlePickerEvent(.trashFileRequested(folderFile(at: filed.movedURL)))
    try await waitUntil { undoManager.canUndo && listedNames(model).isEmpty }
    undoManager.removeAllActions()

    model.returnToInbox(try #require(model.file(row.id)))
    try await waitUntil { undoManager.canUndo }
    try await waitUntil { listedNames(model) == ["2033-10-13 Notenhaus Allegretto.pdf"] }

    undoManager.undo()
    try await waitUntil { listedNames(model).isEmpty }

    undoManager.redo()
    try await waitUntil { listedNames(model) == ["2033-10-13 Notenhaus Allegretto.pdf"] }
  }
}
