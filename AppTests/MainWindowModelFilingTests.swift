import DocsortCore
import Foundation
import Testing

@testable import Docsort

@MainActor
@Suite("MainWindowModel: filing")
struct MainWindowModelFilingTests {
  private let tierarztPath = "Hund Fritzi/Tierarzt"

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
    for folder in [tierarztPath, "Reisen"] {
      try FileManager.default.createDirectory(
        at: environment.archive.appending(path: folder), withIntermediateDirectories: true)
    }
    let model = try await TestWindow.open(on: environment).model
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

  @Test("Filing says in the bottom bar where the file went and offers Undo")
  func filingConfirmsInTheBottomBar() async throws {
    let environment = try TestFolderEnvironment()
    defer { environment.remove() }
    _ = try writeInboxFile(
      named: "Rechnung_NA-33-08812.pdf", in: environment.webDownloads, date: october2033(13))
    try FileManager.default.createDirectory(
      at: environment.archive.appending(path: tierarztPath), withIntermediateDirectories: true)
    let model = try await TestWindow.open(on: environment).model
    model.select(try #require(model.inboxes.orderedRows.first).id)

    try await fileSelected(of: model, filtering: "tierarzt", into: tierarztPath)

    let status = try #require(model.statusMessage?.text)
    #expect(status.contains(tierarztPath))
    #expect(status.contains("Rechnung_NA-33-08812.pdf"))
    #expect(status.contains("Undo"))
  }
}
