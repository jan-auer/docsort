import DocsortCore
import Foundation
import Testing

@testable import Docsort

@MainActor
@Suite("MainWindowModel: Move Back and Put Back")
struct MainWindowModelReturnTests {
  private let notenPath = "Musik Margit/Noten & Bücher"

  @Test("Move Back unmarks the row; undo returns the file to the archive and its filed mark")
  func moveBackAndUndo() async throws {
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
    let file = try #require(model.file(row.id))
    #expect(file.returnToInboxAction == .moveBack)

    model.returnToInbox(file)
    try await waitUntil { model.inboxes.row(for: row.id)?.mark == nil }
    #expect(undoManager.canUndo)

    undoManager.undo()
    try await waitUntil { model.inboxes.row(for: row.id)?.mark == filedMark }
  }

  @Test(
    "A Replace marks the replaced file's row trashed; returning it to its inbox is refused with an alert"
  )
  func replaceMarksReplacedRowTrashed() async throws {
    let environment = try TestFolderEnvironment()
    defer { environment.remove() }
    let invoice = try writeInboxFile(
      named: "Rechnung_NA-33-08812.pdf", in: environment.webDownloads, date: october2033(13))
    let scan = try writeInboxFile(
      named: "2033-10-11_Optik Klarblick.pdf", in: environment.scanner, date: october2033(11))
    let (model, undoManager) = try await TestWindow.open(on: environment)
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
    let replacedMark = try #require(model.inboxes.row(for: invoiceRow.id)?.mark)
    #expect(replacedMark.isTrashed)
    let replacedFile = try #require(model.file(invoiceRow.id))
    #expect(replacedFile.returnToInboxAction == .putBack)

    // Put Back on the replaced row gets the history's refusal; the row stays trashed.
    model.returnToInbox(replacedFile)
    try await waitUntil { model.alert != nil }
    #expect(model.inboxes.row(for: invoiceRow.id)?.mark == replacedMark)
    model.alert = nil

    // A row still showing the invoice as filed there gets Move Back refused, because another file is there now.
    model.inboxes.setMark(invoiceRow.id, invoiceMark)
    model.returnToInbox(try #require(model.file(invoiceRow.id)))
    try await waitUntil { model.alert != nil }
    #expect(
      model.alert?.message == FilingMessages.text(for: .fileChangedSinceFiling(filed.movedURL)))
    #expect(model.inboxes.row(for: invoiceRow.id)?.mark == invoiceMark)
    #expect(model.inboxes.row(for: scanRow.id)?.mark == scanMark)
    // Neither refusal is on the undo stack: ⌘Z still undoes the Replace.
    #expect(undoManager.undoActionName.contains(scan.lastPathComponent))
  }

  @Test("Undoing a Replace puts back the replaced file and its row's filed mark")
  func undoReplaceRestoresReplacedRow() async throws {
    let environment = try TestFolderEnvironment()
    defer { environment.remove() }
    let invoice = try writeInboxFile(
      named: "Rechnung_NA-33-08812.pdf", in: environment.webDownloads, date: october2033(13))
    let scan = try writeInboxFile(
      named: "2033-10-11_Optik Klarblick.pdf", in: environment.scanner, date: october2033(11))
    let (model, undoManager) = try await TestWindow.open(on: environment)
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

    undoManager.redo()
    try await waitUntil { model.inboxes.row(for: invoiceRow.id)?.mark?.isTrashed == true }
    #expect(model.inboxes.row(for: scanRow.id)?.mark?.filedDocumentID != nil)
  }

  @Test(
    "Undoing a Move Back that kept both restores the filed mark onto the moved file's row, not the new file's"
  )
  func undoKeepBothMoveBackMarksMovedRow() async throws {
    let environment = try TestFolderEnvironment()
    defer { environment.remove() }
    let invoice = try writeInboxFile(
      named: "Rechnung_NA-33-08812.pdf", in: environment.webDownloads, date: october2033(13))
    let (model, undoManager) = try await TestWindow.open(on: environment)
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
    // Rows follow the file's identity: the file moved back under the numbered name keeps the invoice's row.
    #expect(numberedRow.id == row.id)
    #expect(numberedRow.mark == nil)
    let downloadRow = try #require(model.inboxes.row(listing: invoice))
    #expect(downloadRow.id != row.id)

    undoManager.undo()
    try await waitUntil { model.inboxes.row(for: numberedRow.id)?.mark == filedMark }
    #expect(model.inboxes.row(for: downloadRow.id)?.mark == nil)

    undoManager.redo()
    try await waitUntil { model.inboxes.row(for: numberedRow.id)?.mark == nil }
    #expect(model.inboxes.row(for: downloadRow.id)?.mark == nil)
  }

  @Test("Put Back unmarks the row; undo trashes it again and redo puts it back again")
  func putBackUndoRedo() async throws {
    let environment = try TestFolderEnvironment()
    defer { environment.remove() }
    let scan = try writeInboxFile(
      named: "2033-10-11_Optik Klarblick.pdf", in: environment.scanner, date: october2033(11))
    let (model, undoManager) = try await TestWindow.open(on: environment)
    let row = try #require(model.inboxes.orderedRows.first)
    let trashed = try await model.filing.trash(scan)
    model.inboxes.setMark(
      row.id, .trashed(trashedURL: trashed.record.trashedURL, date: trashed.event.date))
    let file = try #require(model.file(row.id))
    #expect(file.returnToInboxAction == .putBack)

    model.returnToInbox(file)
    try await waitUntil { model.inboxes.row(for: row.id)?.mark == nil }
    #expect(undoManager.canUndo)

    undoManager.undo()
    try await waitUntil { model.inboxes.row(for: row.id)?.mark?.isTrashed == true }

    undoManager.redo()
    try await waitUntil { model.inboxes.row(for: row.id)?.mark == nil }
  }

  @Test(
    "A filed file can be moved again only once its name or folder changes; renaming it keeps it selected under its new name"
  )
  func renameFiledFileShowsNewName() async throws {
    let environment = try TestFolderEnvironment()
    defer { environment.remove() }
    let invoice = try writeInboxFile(
      named: "Rechnung_NA-33-08812.pdf", in: environment.webDownloads, date: october2033(13))
    let folder = environment.archive.appending(path: notenPath)
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    let (model, undoManager) = try await TestWindow.open(on: environment)
    let row = try #require(model.inboxes.row(listing: invoice))
    let filed = try await model.filing.file(
      invoice, into: folder, archivePath: notenPath, named: invoice.lastPathComponent,
      resolution: .refuse)
    model.inboxes.setMark(
      row.id,
      .filed(
        newURL: filed.movedURL, destinationPath: notenPath, date: filed.event.date,
        documentID: filed.event.documentID))
    model.select(row.id)
    try await waitUntil { model.picker.destination?.path == notenPath }
    #expect(model.filedFileChange == nil)
    #expect(!model.canMoveSelectedFile)

    model.panel.nameText = "2033-10-13 Notenhaus Allegretto"
    #expect(model.filedFileChange == .rename)
    #expect(model.canMoveSelectedFile)
    model.moveSelectedFile()
    try await waitUntil { model.statusMessage != nil }

    let renamedName = "2033-10-13 Notenhaus Allegretto.pdf"
    let status = try #require(model.statusMessage?.text)
    #expect(status.contains(renamedName))
    #expect(undoManager.canUndo)
    #expect(model.selectedFile?.id == row.id)
    #expect(model.selectedFile?.name == renamedName)
    #expect(model.panel.nameText == "2033-10-13 Notenhaus Allegretto")
  }
}

extension InboxLibrary {
  /// The row listing the inbox file at `url`, or `nil` when no section lists one there.
  fileprivate func row(listing url: URL) -> InboxRow? {
    let path = url.standardizedFileURL.path(percentEncoded: false)
    return orderedRows.first { $0.item.url.standardizedFileURL.path(percentEncoded: false) == path }
  }
}
