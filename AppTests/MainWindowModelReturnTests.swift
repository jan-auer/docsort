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
      newURL: filed.movedURL, destinationPath: notenPath, date: filed.event.date)
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
}
