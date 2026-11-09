import DocsortCore
import Foundation
import Testing

@testable import Docsort

@MainActor
@Suite("MainWindowModel: filing")
struct MainWindowModelFilingTests {
  private let tierarztPath = "Hund Fritzi/Tierarzt"

  /// A window model on `environment`'s archive (with the folders `Hund Fritzi/Tierarzt` and `Reisen`, indexed) and
  /// inboxes (scanned once), filing with a history and Trash of the environment.
  private func makeModel(_ environment: TestFolderEnvironment) async throws -> MainWindowModel {
    for folder in [tierarztPath, "Reisen"] {
      try FileManager.default.createDirectory(
        at: environment.archive.appending(path: folder), withIntermediateDirectories: true)
    }
    let folders = FolderLibrary(environment: environment.appEnvironment)
    folders.setArchiveRoot(to: environment.archive)
    folders.addInbox(folder: environment.webDownloads)
    folders.addInbox(folder: environment.scanner)
    let expectedChanges = ExpectedChanges()
    let inboxes = InboxLibrary(watcher: InboxWatcher(expectedChanges: expectedChanges))
    inboxes.update(inboxes: folders.inboxes)
    await inboxes.waitForScan()
    let historyURL = environment.root.appending(path: "FilingHistory.json")
    let service = FilingService(
      historyURL: historyURL,
      recentsPreference: RecentDestinations.preference(in: environment.defaults),
      fileOperations: FileOperations(
        trash: FixtureTrash(folder: environment.root.appending(path: "Trash"))),
      expectedChanges: expectedChanges)
    let model = MainWindowModel(
      folders: folders, inboxes: inboxes, archive: ArchiveLibrary(folders: folders),
      filing: FilingStatusModel(service: service, historyFileURL: historyURL),
      search: SearchSettings(defaults: environment.defaults))
    // The archive library and the picker receive their inputs asynchronously.
    try await waitUntil { model.picker.index?.contains(tierarztPath) == true }
    return model
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

  /// Files the selected file into `path` as ⌘Return in the picker does, with `filter` typed, and waits until the
  /// window has moved on to the next file and the picker has the recents of the move.
  private func fileSelected(of model: MainWindowModel, filtering filter: String, into path: String)
    async throws
  {
    let filed = try #require(model.selectedFile)
    model.picker.filterText = filter
    try #require(model.picker.highlightedPath == path)
    model.picker.requestMove()
    try await waitUntil {
      model.inboxes.row(for: filed.id)?.mark != nil && model.picker.recents.paths.first == path
    }
  }

  @Test(
    "After filing, the next file's picker highlights the folder just used, at the top of Recent")
  func highlightAfterFiling() async throws {
    let environment = try TestFolderEnvironment()
    defer { environment.remove() }
    for (day, name) in [
      (11, "2033-10-11_Optik Klarblick.pdf"), (12, "2033-10-12 Jahreskarte.pdf"),
      (13, "Rechnung_NA-33-08812.pdf"),
    ] {
      _ = try writeInboxFile(named: name, in: environment.webDownloads, date: october2033(day))
    }
    let model = try await makeModel(environment)
    let first = try #require(model.inboxes.orderedRows.first)
    model.select(first.id)
    #expect(model.canMoveSelectedFile)

    try await fileSelected(of: model, filtering: "reisen", into: "Reisen")
    #expect(model.picker.highlightedRowID == "recent:Reisen")

    // Tierarzt is not the top recent: filing moves it there, above Reisen.
    try await fileSelected(of: model, filtering: "tierarzt", into: tierarztPath)
    let next = try #require(model.selectedFile)
    #expect(next.mark == nil)
    #expect(model.picker.filterText == "")
    #expect(model.picker.destination == nil)
    #expect(model.picker.rowSummaries.prefix(2) == [tierarztPath, "Reisen"])
    #expect(model.picker.highlightedRowID == "recent:\(tierarztPath)")
  }
}
