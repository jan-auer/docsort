import DocsortCore
import Foundation
import Testing

@testable import Docsort

/// The inbox library and main window following live changes in the inbox folders, with the real FSEvents watcher on
/// a short quiet interval. Each test changes files only after the first updates arrived and waits for the expected
/// state with a timeout.
@MainActor
@Suite("Live inbox watching")
struct LiveInboxTests {
  let environment: TestFolderEnvironment
  let expectedChanges = ExpectedChanges()
  let folders: FolderLibrary
  let library: InboxLibrary
  /// The external changes the library reported, in order.
  let reported = ReportedChanges()

  init() throws {
    environment = try TestFolderEnvironment()
    folders = FolderLibrary(environment: environment.appEnvironment)
    folders.setArchiveRoot(to: environment.archive)
    folders.addInbox(folder: environment.webDownloads)
    folders.addInbox(folder: environment.scanner)
    library = InboxLibrary(
      watcher: InboxWatcher(
        expectedChanges: expectedChanges,
        timing: WatchTiming(
          quietInterval: .milliseconds(50), maximumDelay: .milliseconds(500),
          retryInterval: .seconds(5))))
  }

  /// Starts watching and waits for the first listing of both inboxes.
  private func startWatching() async {
    library.onExternalChange = { [reported] change in reported.changes.append(change) }
    library.update(inboxes: folders.inboxes)
    await library.waitForScan()
  }

  private func row(named name: String) -> InboxRow? {
    library.orderedRows.first { $0.currentURL.lastPathComponent == name }
  }

  @Test("A file arriving from outside shows the new dot until it is first seen")
  func arrivalShowsNewDot() async throws {
    defer { environment.remove() }
    _ = try writeInboxFile(
      named: "Rechnung_NA-33-08812.pdf", in: environment.webDownloads, date: october2033(13))
    await startWatching()
    #expect(row(named: "Rechnung_NA-33-08812.pdf")?.isNewArrival == false)

    _ = try writeInboxFile(
      named: "2033-10-11_Optik Klarblick.pdf", in: environment.scanner, date: october2033(11))

    #expect(await eventually { row(named: "2033-10-11_Optik Klarblick.pdf") != nil })
    let arrived = try #require(row(named: "2033-10-11_Optik Klarblick.pdf"))
    #expect(arrived.isNewArrival)
    library.markSeen(arrived.id)
    #expect(library.row(for: arrived.id)?.isNewArrival == false)
  }

  @Test("A file renamed outside docsort keeps its row")
  func renameKeepsRow() async throws {
    defer { environment.remove() }
    let invoice = try writeInboxFile(
      named: "Rechnung_NA-33-08812.pdf", in: environment.webDownloads, date: october2033(13))
    await startWatching()
    let before = try #require(row(named: "Rechnung_NA-33-08812.pdf"))

    try FileManager.default.moveItem(
      at: invoice, to: environment.webDownloads.appending(path: "2033-10-13 Notenhaus.pdf"))

    #expect(
      await eventually { library.row(for: before.id)?.item.name == "2033-10-13 Notenhaus.pdf" })
    #expect(library.row(for: before.id)?.isNewArrival == false)
    #expect(reported.changes.isEmpty)
  }

  @Test("A file removed outside docsort loses its row and is reported with the next unhandled file")
  func removalIsReported() async throws {
    defer { environment.remove() }
    let invoice = try writeInboxFile(
      named: "Rechnung_NA-33-08812.pdf", in: environment.webDownloads, date: october2033(13))
    _ = try writeInboxFile(
      named: "2033-10-20 Verlängerung Jahreskarte Konrad.pdf", in: environment.webDownloads,
      date: october2033(20))
    await startWatching()
    let removed = try #require(row(named: "Rechnung_NA-33-08812.pdf"))
    let next = try #require(row(named: "2033-10-20 Verlängerung Jahreskarte Konrad.pdf"))

    try FileManager.default.removeItem(at: invoice)

    #expect(await eventually { library.row(for: removed.id) == nil })
    #expect(
      reported.changes == [
        .removed(
          removed.id, name: "Rechnung_NA-33-08812.pdf", inboxLabel: "Web-Downloads", next: next.id)
      ])
  }

  @Test("A row being filed survives an update applied before its mark, and the mark finds it")
  func updateBeforeMarkKeepsRow() async throws {
    defer { environment.remove() }
    let invoice = try writeInboxFile(
      named: "Rechnung_NA-33-08812.pdf", in: environment.webDownloads, date: october2033(13))
    await startWatching()
    let invoiceRow = try #require(row(named: "Rechnung_NA-33-08812.pdf"))
    let destination = environment.archive.appending(path: "Musik Margit")
    try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
    let service = FilingService(
      historyURL: environment.root.appending(path: "FilingHistory.json"),
      recentsPreference: RecentDestinations.preference(in: environment.defaults),
      fileOperations: FileOperations(), expectedChanges: expectedChanges)

    let outcome = try await library.keepingRow(invoiceRow.id) { () async throws -> MoveOutcome in
      let outcome = try await service.file(
        invoice, into: destination, archivePath: "Musik Margit", named: "Notenhaus.pdf",
        resolution: .refuse)
      // The watcher delivers the inbox without the file before the caller gets to mark the row.
      _ = try writeInboxFile(
        named: "2033-10-20 Verlängerung Jahreskarte Konrad.pdf", in: environment.webDownloads,
        date: october2033(20))
      #expect(
        await eventually { row(named: "2033-10-20 Verlängerung Jahreskarte Konrad.pdf") != nil })
      #expect(library.row(for: invoiceRow.id) != nil)
      return outcome
    }
    library.setMark(
      invoiceRow.id,
      .filed(
        newURL: outcome.movedURL, destinationPath: "Musik Margit", date: outcome.event.date,
        documentID: outcome.event.documentID))

    #expect(library.row(for: invoiceRow.id)?.mark?.filedDocumentID == outcome.event.documentID)
    #expect(reported.changes.isEmpty)
  }

  @Test("A file docsort files keeps its checked-off row, and its move is not reported as a removal")
  func ownMoveIsNotReported() async throws {
    defer { environment.remove() }
    let invoice = try writeInboxFile(
      named: "Rechnung_NA-33-08812.pdf", in: environment.webDownloads, date: october2033(13))
    await startWatching()
    let invoiceRow = try #require(row(named: "Rechnung_NA-33-08812.pdf"))
    let destination = environment.archive.appending(path: "Musik Margit")
    try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
    let service = FilingService(
      historyURL: environment.root.appending(path: "FilingHistory.json"),
      recentsPreference: RecentDestinations.preference(in: environment.defaults),
      fileOperations: FileOperations(
        trash: FixtureTrash(folder: environment.root.appending(path: "Trash"))),
      expectedChanges: expectedChanges)

    let outcome = try await service.file(
      invoice, into: destination, archivePath: "Musik Margit", named: "Notenhaus.pdf",
      resolution: .refuse)
    library.setMark(
      invoiceRow.id,
      .filed(
        newURL: outcome.movedURL, destinationPath: "Musik Margit", date: outcome.event.date,
        documentID: outcome.event.documentID))
    // A later arrival in the same inbox is delivered with or after the move's update.
    _ = try writeInboxFile(
      named: "2033-10-20 Verlängerung Jahreskarte Konrad.pdf", in: environment.webDownloads,
      date: october2033(20))

    #expect(
      await eventually { row(named: "2033-10-20 Verlängerung Jahreskarte Konrad.pdf") != nil })
    #expect(library.row(for: invoiceRow.id)?.mark?.filedDocumentID == outcome.event.documentID)
    #expect(reported.changes.isEmpty)
  }

  @Test(
    "When the selected file is removed outside docsort, the next unfiled file is selected and the bar says so"
  )
  func selectionFollowsRemoval() async throws {
    defer { environment.remove() }
    let invoice = try writeInboxFile(
      named: "Rechnung_NA-33-08812.pdf", in: environment.webDownloads, date: october2033(13))
    _ = try writeInboxFile(
      named: "2033-10-11_Optik Klarblick.pdf", in: environment.scanner, date: october2033(11))
    let historyURL = environment.root.appending(path: "FilingHistory.json")
    let model = MainWindowModel(
      folders: folders, inboxes: library, archive: ArchiveLibrary(),
      filing: FilingStatusModel(
        service: FilingService(
          historyURL: historyURL,
          recentsPreference: RecentDestinations.preference(in: environment.defaults),
          fileOperations: FileOperations(), expectedChanges: expectedChanges),
        historyFileURL: historyURL),
      search: SearchSettings(defaults: environment.defaults))
    library.update(inboxes: folders.inboxes)
    await library.waitForScan()
    let selected = try #require(row(named: "Rechnung_NA-33-08812.pdf"))
    let next = try #require(row(named: "2033-10-11_Optik Klarblick.pdf"))
    model.select(selected.id)

    try FileManager.default.removeItem(at: invoice)

    #expect(await eventually { model.sidebarSelection == .item(next.id) })
    #expect(
      model.statusMessage?.text
        == "“Rechnung_NA-33-08812.pdf” was removed from Web-Downloads outside docsort.")
  }

  /// Whether `condition` holds within 10 seconds, checked every 20 ms while the main actor is free to apply updates.
  private func eventually(_ condition: () -> Bool) async -> Bool {
    let deadline = ContinuousClock.now + .seconds(10)
    while !condition() {
      guard ContinuousClock.now < deadline else { return false }
      do {
        try await Task.sleep(for: .milliseconds(20))
      } catch {
        // Cancelled: the test is over.
        return false
      }
    }
    return true
  }
}

/// The external changes an `InboxLibrary` reported, collected on the main actor.
@MainActor
final class ReportedChanges {
  var changes: [InboxExternalChange] = []
}
