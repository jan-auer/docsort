import DocsortCore
import Foundation
import Testing

@testable import Docsort

@MainActor
@Suite("MainWindowModel: Move Back and Put Back")
struct MainWindowModelReturnTests {
  private let notenPath = "Musik Margit/Noten & Bücher"

  private func exists(_ url: URL) -> Bool {
    FileManager.default.fileExists(atPath: url.path(percentEncoded: false))
  }

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
    #expect(exists(scan))
    #expect(exists(filed.movedURL))

    undoManager.redo()
    try await waitUntil { model.inboxes.row(for: invoiceRow.id)?.mark?.isTrashed == true }
    #expect(model.inboxes.row(for: scanRow.id)?.mark?.filedDocumentID != nil)
    #expect(!exists(scan))
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
    let (model, undoManager) = try await TestWindow.open(on: environment)
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
    let (model, _) = try await TestWindow.open(on: environment)
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

extension InboxLibrary {
  /// The row listing the inbox file at `url`, or `nil` when no section lists one there.
  fileprivate func row(listing url: URL) -> InboxRow? {
    let path = url.standardizedFileURL.path(percentEncoded: false)
    return orderedRows.first { $0.item.url.standardizedFileURL.path(percentEncoded: false) == path }
  }
}
