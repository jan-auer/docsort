import DocsortCore
import Foundation
import Testing

@testable import Docsort

@MainActor
@Suite("MainWindowModel: Move Back and Put Back")
struct MainWindowModelReturnTests {
  private let notenPath = "Musik Margit/Noten & Bücher"

  /// A window model on `environment`'s archive and inboxes (scanned once), filing with a history and Trash of the
  /// environment, and the undo manager it registers with.
  private func makeModel(
    _ environment: TestFolderEnvironment
  ) async -> (model: MainWindowModel, undoManager: UndoManager) {
    let folders = FolderLibrary(environment: environment.appEnvironment)
    folders.setArchiveRoot(to: environment.archive)
    folders.addInbox(folder: environment.webDownloads)
    folders.addInbox(folder: environment.scanner)
    let inboxes = InboxLibrary()
    inboxes.update(inboxes: folders.inboxes)
    await inboxes.waitForScan()
    let historyURL = environment.root.appending(path: "FilingHistory.json")
    let service = FilingService(
      historyURL: historyURL,
      recentsPreference: RecentDestinations.preference(in: environment.defaults),
      fileOperations: FileOperations(
        trash: FixtureTrash(folder: environment.root.appending(path: "Trash"))))
    let model = MainWindowModel(
      folders: folders, inboxes: inboxes, archive: ArchiveLibrary(),
      filing: FilingModel(service: service, historyFileURL: historyURL),
      search: SearchSettings(defaults: environment.defaults))
    let undoManager = UndoManager()
    model.undoManager = undoManager
    return (model, undoManager)
  }

  /// Waits up to five seconds for `condition`, which the model's asynchronous actions make true.
  private func waitUntil(_ condition: () -> Bool) async throws {
    let deadline = ContinuousClock.now + .seconds(5)
    while !condition() {
      guard ContinuousClock.now < deadline else {
        Issue.record("Timed out waiting for the model")
        return
      }
      try await Task.sleep(for: .milliseconds(10))
    }
  }

  private func exists(_ url: URL) -> Bool {
    FileManager.default.fileExists(atPath: url.path(percentEncoded: false))
  }

  @Test("Move Back unmarks the row; undo returns the file to the archive and its filed mark")
  func moveBackAndUndo() async throws {
    let environment = try TestFolderEnvironment()
    defer { environment.remove() }
    let invoice = try writeInboxFile(
      named: "Rechnung_NA-33-08812.pdf", in: environment.webDownloads, date: october2033(13))
    let (model, undoManager) = await makeModel(environment)
    let row = try #require(model.inboxes.orderedRows.first)
    let filed = try await model.filing.file(
      invoice, into: environment.archive.appending(path: notenPath), archivePath: notenPath,
      named: "2033-10-13 Notenhaus Allegretto.pdf", resolution: .refuse)
    let filedMark = InboxItemMark.filed(
      newURL: filed.movedURL, destinationPath: notenPath, date: filed.event.date,
      documentID: filed.event.documentID)
    model.inboxes.setMark(row.id, filedMark)
    let file = try #require(model.file(row.id))
    #expect(file.returnToInboxAction == .moveBack)

    model.returnToInbox(file)
    try await waitUntil { model.inboxes.row(for: row.id)?.mark == nil }
    #expect(exists(invoice))
    #expect(!exists(filed.movedURL))
    #expect(undoManager.undoActionName == "Move Back of “Rechnung_NA-33-08812.pdf”")

    undoManager.undo()
    try await waitUntil { model.inboxes.row(for: row.id)?.mark == filedMark }
    #expect(exists(filed.movedURL))
    #expect(!exists(invoice))
  }

  @Test(
    "A Replace marks the replaced file's row trashed; returning it to its inbox leaves the replacing file in place"
  )
  func replaceMarksReplacedRowTrashed() async throws {
    let environment = try TestFolderEnvironment()
    defer { environment.remove() }
    let invoice = try writeInboxFile(
      named: "Rechnung_NA-33-08812.pdf", in: environment.webDownloads, date: october2033(13))
    let scan = try writeInboxFile(
      named: "2033-10-11_Optik Klarblick.pdf", in: environment.scanner, date: october2033(11))
    let (model, undoManager) = await makeModel(environment)
    let invoiceRow = try #require(model.inboxes.row(listing: invoice))
    let scanRow = try #require(model.inboxes.row(listing: scan))
    let folder = environment.archive.appending(path: notenPath)
    let filedName = "2033-10-13 Notenhaus Allegretto.pdf"
    let filed = try await model.filing.file(
      invoice, into: folder, archivePath: notenPath, named: filedName, resolution: .refuse)
    let invoiceMark = InboxItemMark.filed(
      newURL: filed.movedURL, destinationPath: notenPath, date: filed.event.date,
      documentID: filed.event.documentID)
    model.inboxes.setMark(invoiceRow.id, invoiceMark)
    let archived = filed.movedURL

    // The scan is filed under the same name with Replace, as the conflict alert does.
    model.resolve(
      FilingConflict(
        existingName: filedName,
        request: MoveRequest(
          itemID: scanRow.id, source: scan, folderURL: folder, archivePath: notenPath,
          name: filedName, originalName: scan.lastPathComponent, kind: .filing)),
      with: .replace)
    try await waitUntil { model.inboxes.row(for: scanRow.id)?.mark != nil }

    let scanMark = try #require(model.inboxes.row(for: scanRow.id)?.mark)
    #expect(scanMark.filedDocumentID != filed.event.documentID)
    guard case .trashed(let trashedURL, _)? = model.inboxes.row(for: invoiceRow.id)?.mark else {
      Issue.record("The replaced invoice's row is not marked trashed")
      return
    }
    #expect(FileManager.default.fileExists(atPath: trashedURL.path(percentEncoded: false)))
    let replacedFile = try #require(model.file(invoiceRow.id))
    #expect(replacedFile.returnToInboxAction == .putBack)

    // Put Back on the replaced row gets the history's refusal.
    model.returnToInbox(replacedFile)
    try await waitUntil { model.alert != nil }
    #expect(model.alert?.message == "This file was replaced by a move; undo that move instead.")
    #expect(exists(archived))
    model.alert = nil

    // A row still showing the invoice as filed there (as before this fix) gets Move Back refused.
    model.inboxes.setMark(invoiceRow.id, invoiceMark)
    model.returnToInbox(try #require(model.file(invoiceRow.id)))
    try await waitUntil { model.alert != nil }
    #expect(model.alert?.message == "This file has changed since it was filed.")
    #expect(exists(archived))
    #expect(!exists(scan))
    #expect(!exists(invoice))
    #expect(model.inboxes.row(for: scanRow.id)?.mark == scanMark)
    #expect(undoManager.undoActionName == "Move of “2033-10-11_Optik Klarblick.pdf”")
  }

  @Test("Undoing a Replace puts back the replaced file and its row's filed mark")
  func undoReplaceRestoresReplacedRow() async throws {
    let environment = try TestFolderEnvironment()
    defer { environment.remove() }
    let invoice = try writeInboxFile(
      named: "Rechnung_NA-33-08812.pdf", in: environment.webDownloads, date: october2033(13))
    let scan = try writeInboxFile(
      named: "2033-10-11_Optik Klarblick.pdf", in: environment.scanner, date: october2033(11))
    let (model, undoManager) = await makeModel(environment)
    let invoiceRow = try #require(model.inboxes.row(listing: invoice))
    let scanRow = try #require(model.inboxes.row(listing: scan))
    let folder = environment.archive.appending(path: notenPath)
    let filedName = "2033-10-13 Notenhaus Allegretto.pdf"
    let filed = try await model.filing.file(
      invoice, into: folder, archivePath: notenPath, named: filedName, resolution: .refuse)
    let invoiceMark = InboxItemMark.filed(
      newURL: filed.movedURL, destinationPath: notenPath, date: filed.event.date,
      documentID: filed.event.documentID)
    model.inboxes.setMark(invoiceRow.id, invoiceMark)
    model.resolve(
      FilingConflict(
        existingName: filedName,
        request: MoveRequest(
          itemID: scanRow.id, source: scan, folderURL: folder, archivePath: notenPath,
          name: filedName, originalName: scan.lastPathComponent, kind: .filing)),
      with: .replace)
    try await waitUntil { model.inboxes.row(for: invoiceRow.id)?.mark?.isTrashed == true }

    undoManager.undo()
    try await waitUntil { model.inboxes.row(for: invoiceRow.id)?.mark == invoiceMark }
    #expect(model.inboxes.row(for: scanRow.id)?.mark == nil)
    #expect(exists(scan))
    #expect(exists(filed.movedURL))

    undoManager.redo()
    try await waitUntil { model.inboxes.row(for: invoiceRow.id)?.mark?.isTrashed == true }
    #expect(model.inboxes.row(for: scanRow.id)?.mark?.filedDocumentID != nil)
    #expect(!exists(scan))
  }

  @Test(
    "Undoing a Move Back that kept both restores the filed mark onto the numbered row, not the new file's"
  )
  func undoKeepBothMoveBackMarksMovedRow() async throws {
    let environment = try TestFolderEnvironment()
    defer { environment.remove() }
    let invoice = try writeInboxFile(
      named: "Rechnung_NA-33-08812.pdf", in: environment.webDownloads, date: october2033(13))
    let (model, undoManager) = await makeModel(environment)
    let row = try #require(model.inboxes.row(listing: invoice))
    let filed = try await model.filing.file(
      invoice, into: environment.archive.appending(path: notenPath), archivePath: notenPath,
      named: "2033-10-13 Notenhaus Allegretto.pdf", resolution: .refuse)
    let filedMark = InboxItemMark.filed(
      newURL: filed.movedURL, destinationPath: notenPath, date: filed.event.date,
      documentID: filed.event.documentID)
    model.inboxes.setMark(row.id, filedMark)
    // A new download takes the invoice's inbox name.
    _ = try writeInboxFile(
      named: "Rechnung_NA-33-08812.pdf", in: environment.webDownloads, date: october2033(20))

    model.returnToInbox(try #require(model.file(row.id)))
    try await waitUntil { model.moveBackConflict != nil }
    model.resolve(try #require(model.moveBackConflict))
    let numbered = environment.webDownloads.appending(path: "Rechnung_NA-33-08812 2.pdf")
    try await waitUntil { model.inboxes.row(listing: numbered) != nil }
    let numberedRow = try #require(model.inboxes.row(listing: numbered))
    #expect(numberedRow.mark == nil)

    undoManager.undo()
    try await waitUntil { model.inboxes.row(for: numberedRow.id)?.mark == filedMark }
    #expect(model.inboxes.row(for: row.id)?.mark == nil)
    #expect(exists(filed.movedURL))
    #expect(!exists(numbered))
    #expect(exists(invoice))

    undoManager.redo()
    try await waitUntil { model.inboxes.row(for: numberedRow.id)?.mark == nil }
    #expect(exists(numbered))
    #expect(!exists(filed.movedURL))
  }

  @Test("Put Back unmarks the row; undo trashes it again and redo puts it back again")
  func putBackUndoRedo() async throws {
    let environment = try TestFolderEnvironment()
    defer { environment.remove() }
    let scan = try writeInboxFile(
      named: "2033-10-11_Optik Klarblick.pdf", in: environment.scanner, date: october2033(11))
    let (model, undoManager) = await makeModel(environment)
    let row = try #require(model.inboxes.orderedRows.first)
    let trashed = try await model.filing.trash(scan)
    model.inboxes.setMark(
      row.id, .trashed(trashedURL: trashed.record.trashedURL, date: trashed.event.date))
    let file = try #require(model.file(row.id))
    #expect(file.returnToInboxAction == .putBack)

    model.returnToInbox(file)
    try await waitUntil { model.inboxes.row(for: row.id)?.mark == nil }
    #expect(exists(scan))
    #expect(undoManager.undoActionName == "Put Back of “2033-10-11_Optik Klarblick.pdf”")

    undoManager.undo()
    try await waitUntil { model.inboxes.row(for: row.id)?.mark?.isTrashed == true }
    #expect(!exists(scan))

    undoManager.redo()
    try await waitUntil { model.inboxes.row(for: row.id)?.mark == nil }
    #expect(exists(scan))
  }

  @Test("Renaming a filed file keeps it selected and shows its new name")
  func renameFiledFileShowsNewName() async throws {
    let environment = try TestFolderEnvironment()
    defer { environment.remove() }
    let invoice = try writeInboxFile(
      named: "Rechnung_NA-33-08812.pdf", in: environment.webDownloads, date: october2033(13))
    let (model, _) = await makeModel(environment)
    let row = try #require(model.inboxes.row(listing: invoice))
    let folder = environment.archive.appending(path: notenPath)
    let filed = try await model.filing.file(
      invoice, into: folder, archivePath: notenPath, named: invoice.lastPathComponent,
      resolution: .refuse)
    model.inboxes.setMark(
      row.id,
      .filed(
        newURL: filed.movedURL, destinationPath: notenPath, date: filed.event.date,
        documentID: filed.event.documentID))
    model.select(row.id)

    let renamedName = "2033-10-13 Notenhaus Allegretto.pdf"
    model.resolve(
      FilingConflict(
        existingName: renamedName,
        request: MoveRequest(
          itemID: row.id, source: filed.movedURL, folderURL: folder, archivePath: notenPath,
          name: renamedName, originalName: invoice.lastPathComponent,
          kind: .renaming(documentID: filed.event.documentID))),
      with: .refuse)
    try await waitUntil { model.statusMessage != nil }

    #expect(model.statusMessage?.text == "Renamed to \(renamedName) · Undo ⌘Z")
    #expect(model.selectedFile?.id == row.id)
    #expect(model.selectedFile?.name == renamedName)
    #expect(model.panel.nameText == "2033-10-13 Notenhaus Allegretto")
  }
}
