import DocsortCore
import Foundation
import Testing

@testable import Docsort

@MainActor
@Suite("InboxLibrary")
struct InboxLibraryTests {
  /// A library listing `environment`'s two inboxes, Web-Downloads then Scanner, scanned once.
  private func makeLibrary(_ environment: TestFolderEnvironment) async -> InboxLibrary {
    let folders = FolderLibrary(environment: environment.appEnvironment)
    folders.setArchiveRoot(to: environment.archive)
    folders.addInbox(folder: environment.webDownloads)
    folders.addInbox(folder: environment.scanner)
    let library = InboxLibrary()
    library.update(inboxes: folders.inboxes)
    await library.waitForScan()
    return library
  }

  private func names(_ library: InboxLibrary) -> [String] {
    library.orderedRows.map(\.item.name)
  }

  @Test("A filed file that left the inbox keeps its row and its place across a rescan")
  func marksSurviveRescan() async throws {
    let environment = try TestFolderEnvironment()
    defer { environment.remove() }
    _ = try writeInboxFile(
      named: "Rechnung_NA-33-08812.pdf", in: environment.webDownloads, date: october2033(13))
    let renewal = try writeInboxFile(
      named: "2033-10-20 Verlängerung Jahreskarte Konrad.pdf", in: environment.webDownloads,
      date: october2033(20))
    _ = try writeInboxFile(
      named: "Rechnung_Collegegeld_1e-termijn.pdf",
      in: environment.webDownloads.appending(path: "Uni Westerholm"), date: october2033(7))
    let library = await makeLibrary(environment)
    let before = names(library)
    #expect(
      before == [
        "Rechnung_Collegegeld_1e-termijn.pdf", "Rechnung_NA-33-08812.pdf",
        "2033-10-20 Verlängerung Jahreskarte Konrad.pdf",
      ])

    let groupRow = try #require(library.orderedRows.first)
    let renewalRow = try #require(library.orderedRows.last)
    let archived = environment.archive.appending(path: "Mobilität/Jahreskarte Regio Plus")
    try FileManager.default.createDirectory(at: archived, withIntermediateDirectories: true)
    try FileManager.default.moveItem(
      at: renewal, to: archived.appending(path: renewal.lastPathComponent))
    try FileManager.default.removeItem(
      at: environment.webDownloads.appending(path: "Uni Westerholm"))
    let filedMark = InboxItemMark.filed(
      newURL: archived.appending(path: renewal.lastPathComponent),
      destinationPath: "Mobilität/Jahreskarte Regio Plus", date: october2033(21),
      documentID: UUID())
    let trashedMark = InboxItemMark.trashed(
      trashedURL: environment.root.appending(path: "Trash/Rechnung_Collegegeld_1e-termijn.pdf"),
      date: october2033(21))
    library.setMark(renewalRow.id, filedMark)
    library.setMark(groupRow.id, trashedMark)

    library.refresh()
    await library.waitForScan()

    #expect(names(library) == before)
    #expect(library.row(for: renewalRow.id)?.mark == filedMark)
    #expect(library.row(for: groupRow.id)?.mark == trashedMark)

    library.setMark(renewalRow.id, nil)
    #expect(library.row(for: renewalRow.id)?.mark == nil)
    library.refresh()
    await library.waitForScan()
    #expect(library.row(for: renewalRow.id) == nil)
  }

  @Test("A new file arriving under a filed file's name is listed unfiled after a rescan")
  func newFileUnderFiledNameIsUnfiled() async throws {
    let environment = try TestFolderEnvironment()
    defer { environment.remove() }
    let invoice = try writeInboxFile(
      named: "Rechnung_NA-33-08812.pdf", in: environment.webDownloads, date: october2033(13))
    let library = await makeLibrary(environment)
    let invoiceRow = try #require(library.orderedRows.first)

    let archived = environment.archive.appending(path: "Musik Margit/Noten & Bücher")
    try FileManager.default.createDirectory(at: archived, withIntermediateDirectories: true)
    try FileManager.default.moveItem(
      at: invoice, to: archived.appending(path: "2033-10-13 Notenhaus Allegretto.pdf"))
    library.setMark(
      invoiceRow.id,
      .filed(
        newURL: archived.appending(path: "2033-10-13 Notenhaus Allegretto.pdf"),
        destinationPath: "Musik Margit/Noten & Bücher", date: october2033(13),
        documentID: UUID()))
    _ = try writeInboxFile(
      named: "Rechnung_NA-33-08812.pdf", in: environment.webDownloads, date: october2033(20))

    library.refresh()
    await library.waitForScan()

    #expect(names(library) == ["Rechnung_NA-33-08812.pdf"])
    let newRow = try #require(library.orderedRows.first)
    #expect(newRow.mark == nil)
    #expect(
      newRow.currentURL == environment.webDownloads.appending(path: "Rechnung_NA-33-08812.pdf"))
  }

  @Test("The next unhandled file skips handled ones and wraps across sections")
  func nextUnhandledWraps() async throws {
    let environment = try TestFolderEnvironment()
    defer { environment.remove() }
    _ = try writeInboxFile(
      named: "Rechnung_NA-33-08812.pdf", in: environment.webDownloads, date: october2033(13))
    _ = try writeInboxFile(
      named: "2033-10-20 Verlängerung Jahreskarte Konrad.pdf", in: environment.webDownloads,
      date: october2033(20))
    _ = try writeInboxFile(
      named: "2033-10-11_Optik Klarblick.pdf", in: environment.scanner, date: october2033(11))
    let library = await makeLibrary(environment)
    let rows = library.orderedRows
    #expect(rows.count == 3)

    #expect(library.nextUnhandledRow(after: rows[0].id)?.id == rows[1].id)
    library.setMark(
      rows[1].id,
      .trashed(
        trashedURL: environment.root.appending(
          path: "Trash/2033-10-20 Verlängerung Jahreskarte Konrad.pdf"),
        date: october2033(21)))
    #expect(library.nextUnhandledRow(after: rows[0].id)?.id == rows[2].id)
    #expect(library.nextUnhandledRow(after: rows[2].id)?.id == rows[0].id)
    #expect(library.firstRow(inSection: 1)?.item.name == "2033-10-11_Optik Klarblick.pdf")
    #expect(library.sections.map(\.label) == ["Web-Downloads", "Scanner"])
  }
}
