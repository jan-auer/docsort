import DocsortCore
import Foundation
import Testing

@testable import Docsort

@MainActor
@Suite("HistoryModel")
struct HistoryModelTests {
  private let notenPath = "Musik Margit/Noten & Bücher"

  /// A Gregorian calendar in UTC, so days don't depend on the machine's time zone.
  private var utcCalendar: Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = .gmt
    return calendar
  }

  /// `day` October 2033 at `hour`:00 UTC.
  private func dateInOctober2033(_ day: Int, hour: Int) -> Date {
    utcCalendar.date(from: DateComponents(year: 2033, month: 10, day: day, hour: hour))!
  }

  /// An entry filed at `date` from Web-Downloads, named `originalName` before and `newName` after.
  private func entry(
    _ date: Date, _ originalName: String, _ newName: String, destination: String,
    place: HistoryEntryPlace = .current
  ) -> HistoryEntry {
    HistoryEntry(
      id: UUID(), documentID: UUID(), date: date, kind: .filed, originalName: originalName,
      inboxName: "Web-Downloads", newName: newName, destination: destination,
      url: URL(filePath: "/Archiv/\(destination)/\(newName)"), place: place)
  }

  // MARK: Grouping and search

  @Test("Entries are grouped by day, oldest day and oldest entry first")
  func groupsByDay() {
    let entries = [
      entry(
        dateInOctober2033(13, hour: 9), "Rechnung_NA-33-08812.pdf",
        "2033-10-13 Notenhaus Allegretto.pdf", destination: notenPath),
      entry(
        dateInOctober2033(13, hour: 17), "2033-10-11_Optik Klarblick.pdf",
        "2033-10-11 Optik Klarblick Rechnung.pdf",
        destination: "Gesundheit/Konrad/Augenarzt & Brillen"),
      entry(
        dateInOctober2033(20, hour: 8), "2033-10-20 Verlängerung Jahreskarte Konrad.pdf",
        "2033-10-20 Verlängerung Jahreskarte Konrad.pdf",
        destination: "Mobilität/Jahreskarte Regio Plus"),
    ]

    let days = HistoryModel.days(grouping: entries, in: utcCalendar)

    #expect(days.map(\.id) == [dateInOctober2033(13, hour: 0), dateInOctober2033(20, hour: 0)])
    #expect(
      days.map { $0.entries.map(\.id) } == [[entries[0].id, entries[1].id], [entries[2].id]])
  }

  @Test("Day titles name today and yesterday")
  func dayTitles() {
    let now = dateInOctober2033(20, hour: 12)
    let today = HistoryDay(id: dateInOctober2033(20, hour: 0), entries: [])
    let yesterday = HistoryDay(id: dateInOctober2033(19, hour: 0), entries: [])
    let earlier = HistoryDay(id: dateInOctober2033(13, hour: 0), entries: [])

    #expect(today.title(now: now, calendar: utcCalendar).hasPrefix("Today · "))
    #expect(yesterday.title(now: now, calendar: utcCalendar).hasPrefix("Yesterday · "))
    let earlierTitle = earlier.title(now: now, calendar: utcCalendar)
    #expect(!earlierTitle.hasPrefix("Today") && !earlierTitle.hasPrefix("Yesterday"))
    #expect(earlierTitle.contains("2033"))
  }

  @Test("The search matches every word in any column, ignoring case and diacritics")
  func searchMatchesAllWords() {
    let allegretto = entry(
      dateInOctober2033(13, hour: 9), "Rechnung_NA-33-08812.pdf",
      "2033-10-13 Notenhaus Allegretto.pdf",
      destination: notenPath)
    let jahreskarte = entry(
      dateInOctober2033(20, hour: 8), "2033-10-20 Verlängerung Jahreskarte Konrad.pdf",
      "2033-10-20 Verlängerung Jahreskarte Konrad.pdf",
      destination: "Mobilität/Jahreskarte Regio Plus",
      place: .undone(dateInOctober2033(20, hour: 9)))
    let entries = [allegretto, jahreskarte]

    #expect(HistoryModel.entries(entries, matching: "") == entries)
    #expect(HistoryModel.entries(entries, matching: "verlangerung MOBILITAT") == [jahreskarte])
    #expect(HistoryModel.entries(entries, matching: "noten web-downloads") == [allegretto])
    #expect(HistoryModel.entries(entries, matching: "undone") == [jahreskarte])
    #expect(HistoryModel.entries(entries, matching: "noten konrad").isEmpty)
  }

  // MARK: Entries from the history

  @Test("Events become entries with their kind, inbox, destination and place")
  func entriesFromEvents() throws {
    let archive = URL(filePath: "/Volumes/Daten/Archiv", directoryHint: .isDirectory)
    let inbox = archive.appending(path: "_Neu/Web-Downloads", directoryHint: .isDirectory)
    let noten = archive.appending(path: notenPath, directoryHint: .isDirectory)
    let invoice = inbox.appending(path: "Rechnung_NA-33-08812.pdf")
    let filedInvoice = noten.appending(path: "Rechnung_NA-33-08812.pdf")
    let renamedInvoice = noten.appending(path: "2033-10-13 Notenhaus Allegretto.pdf")
    let pass = inbox.appending(path: "2033-10-20 Verlängerung Jahreskarte Konrad.pdf")
    let trashedPass = URL(filePath: "/Volumes/Daten/.Trashes/501/\(pass.lastPathComponent)")
    let identity = FileIdentity(volumeUUID: nil, fileID: 1)
    var history = FilingHistory()
    let filed = history.recordMove(
      MoveRecord(
        originalURL: invoice, destinationURL: filedInvoice, createdFolders: [], replaced: nil,
        movedItem: identity), at: dateInOctober2033(13, hour: 9))
    let renamed = history.recordMove(
      MoveRecord(
        originalURL: filedInvoice, destinationURL: renamedInvoice, createdFolders: [],
        replaced: nil, movedItem: identity), at: dateInOctober2033(13, hour: 10))
    let movedBack = history.recordMove(
      MoveRecord(
        originalURL: renamedInvoice, destinationURL: invoice, createdFolders: [], replaced: nil,
        movedItem: identity), at: dateInOctober2033(13, hour: 11))
    let trashed = history.recordTrash(
      TrashRecord(originalURL: pass, trashedURL: trashedPass, trashedItem: identity),
      at: dateInOctober2033(20, hour: 8))
    try history.recordUndo(
      of: trashed.id, restoredTo: RestoredItem(url: pass, identity: identity),
      at: dateInOctober2033(20, hour: 9))
    let folders = HistoryFolders(
      archiveRoot: archive, inboxes: [HistoryFolders.Inbox(label: "Web-Downloads", url: inbox)])

    let entries = HistoryListing.entries(from: history.events, folders: folders) { _ in true }

    #expect(entries.map(\.id) == [filed.id, renamed.id, movedBack.id, trashed.id])
    #expect(entries.map(\.documentID) == [filed, renamed, movedBack, trashed].map(\.documentID))
    #expect(entries.map(\.kind) == [.filed, .renamed, .movedBack, .trashed])
    #expect(entries.map(\.inboxName) == Array(repeating: "Web-Downloads", count: 4))
    #expect(
      entries.map(\.destination) == [
        notenPath, notenPath, "Web-Downloads (moved back from \(notenPath))", "Trash",
      ])
    #expect(
      entries.map(\.newName) == [
        "Rechnung_NA-33-08812.pdf", "2033-10-13 Notenhaus Allegretto.pdf",
        "Rechnung_NA-33-08812.pdf", nil,
      ])
    #expect(
      entries.map(\.place) == [
        .movedOrDeleted, .movedOrDeleted, .current, .undone(dateInOctober2033(20, hour: 9)),
      ])

    let missing = HistoryListing.entries(from: [movedBack], folders: folders) { _ in false }
    #expect(missing.map(\.place) == [.movedOrDeleted])
  }

  // MARK: Actions

  /// A History over a window model on `environment`'s archive and inboxes (scanned once), filing with a history and
  /// Trash of the environment.
  private func makeModel(_ environment: TestFolderEnvironment) async -> HistoryModel {
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
    let mainWindow = MainWindowModel(
      folders: folders, inboxes: inboxes, archive: ArchiveLibrary(),
      filing: FilingModel(service: service, historyFileURL: historyURL),
      search: SearchSettings(defaults: environment.defaults))
    return HistoryModel(mainWindow: mainWindow, calendar: utcCalendar)
  }

  private func exists(_ url: URL) -> Bool {
    FileManager.default.fileExists(atPath: url.path(percentEncoded: false))
  }

  @Test("Move Back and Put Back are offered where allowed and unmark the main window's rows")
  func moveBackAndPutBack() async throws {
    let environment = try TestFolderEnvironment()
    defer { environment.remove() }
    let invoice = try writeInboxFile(
      named: "Rechnung_NA-33-08812.pdf", in: environment.webDownloads, date: october2033(13))
    let scan = try writeInboxFile(
      named: "2033-10-11_Optik Klarblick.pdf", in: environment.scanner, date: october2033(11))
    let history = await makeModel(environment)
    let inboxes = history.mainWindow.inboxes
    let invoiceRow = try #require(
      inboxes.orderedRows.first { $0.item.name == invoice.lastPathComponent })
    let scanRow = try #require(inboxes.orderedRows.first { $0.item.name == scan.lastPathComponent })
    let filing = history.mainWindow.filing
    let filed = try await filing.file(
      invoice, into: environment.archive.appending(path: notenPath), archivePath: notenPath,
      named: "2033-10-13 Notenhaus Allegretto.pdf", resolution: .refuse)
    inboxes.setMark(
      invoiceRow.id,
      .filed(
        newURL: filed.movedURL, destinationPath: notenPath, date: filed.event.date,
        documentID: filed.event.documentID))
    let trashed = try await filing.trash(scan)
    inboxes.setMark(
      scanRow.id, .trashed(trashedURL: trashed.record.trashedURL, date: trashed.event.date))

    await history.refresh()

    let filedEntry = try #require(history.entries.first)
    let trashedEntry = try #require(history.entries.last)
    #expect(history.entries.map(\.kind) == [.filed, .trashed])
    #expect(history.selection == trashedEntry.id)
    #expect(history.countText == "2 entries")
    #expect(filedEntry.inboxName == "Web-Downloads")
    #expect(filedEntry.destination == notenPath)
    #expect(history.canOpen(filedEntry))
    #expect(history.returnAction(for: filedEntry) == .moveBack)
    #expect(history.canReturnToInbox(filedEntry))
    #expect(history.inboxRowID(for: filedEntry) == invoiceRow.id)
    #expect(history.returnAction(for: trashedEntry) == .putBack)
    #expect(history.inboxRowID(for: trashedEntry) == scanRow.id)

    await history.returnToInbox(filedEntry)

    #expect(exists(invoice))
    #expect(!exists(filed.movedURL))
    #expect(inboxes.row(for: invoiceRow.id)?.mark == nil)
    #expect(history.entries.map(\.kind) == [.filed, .trashed, .movedBack])
    let movedBackEntry = try #require(history.entries.last)
    #expect(history.selection == movedBackEntry.id)
    #expect(movedBackEntry.isCurrent)
    #expect(history.returnAction(for: movedBackEntry) == nil)
    let supersededEntry = try #require(history.entries.first)
    #expect(supersededEntry.place == .movedOrDeleted)
    #expect(!history.canOpen(supersededEntry))
    #expect(history.returnAction(for: supersededEntry) == nil)

    let currentTrashedEntry = try #require(history.entries.first { $0.id == trashedEntry.id })
    await history.returnToInbox(currentTrashedEntry)

    #expect(exists(scan))
    #expect(inboxes.row(for: scanRow.id)?.mark == nil)
    let undoneEntry = try #require(history.entries.first { $0.id == trashedEntry.id })
    guard case .undone = undoneEntry.place else {
      Issue.record("The trashed entry should be undone, is \(undoneEntry.place)")
      return
    }
    #expect(history.returnAction(for: undoneEntry) == nil)
    #expect(history.alert == nil)
  }

  @Test("Move Back from a stale entry refuses when a Replace took the filed file's place")
  func moveBackRefusesReplacedFile() async throws {
    let environment = try TestFolderEnvironment()
    defer { environment.remove() }
    let filedName = "2033-10-13 Notenhaus Allegretto.pdf"
    let invoice = try writeInboxFile(
      named: "Rechnung_NA-33-08812.pdf", in: environment.webDownloads, date: october2033(13))
    let scan = try writeInboxFile(
      named: "2033-10-13_Notenhaus.pdf", in: environment.scanner, date: october2033(13))
    let history = await makeModel(environment)
    let inboxes = history.mainWindow.inboxes
    let invoiceRow = try #require(
      inboxes.orderedRows.first { $0.item.name == invoice.lastPathComponent })
    let scanRow = try #require(inboxes.orderedRows.first { $0.item.name == scan.lastPathComponent })
    let filing = history.mainWindow.filing
    let noten = environment.archive.appending(path: notenPath)
    let filed = try await filing.file(
      invoice, into: noten, archivePath: notenPath, named: filedName, resolution: .refuse)
    inboxes.setMark(
      invoiceRow.id,
      .filed(
        newURL: filed.movedURL, destinationPath: notenPath, date: filed.event.date,
        documentID: filed.event.documentID))
    await history.refresh()
    let staleEntry = try #require(history.entries.first)
    #expect(history.inboxRowID(for: staleEntry) == invoiceRow.id)

    // The main window files the scan under the same name with Replace; the History is not read again.
    let replacing = try await filing.file(
      scan, into: noten, archivePath: notenPath, named: filedName, resolution: .replace)
    let replacedEvent = try #require(replacing.replacedEvent)
    guard case .trashed(let replacedRecord) = replacedEvent.action else {
      Issue.record("The Replace should trash the filed file, did \(replacedEvent.action)")
      return
    }
    inboxes.setMark(
      invoiceRow.id, .trashed(trashedURL: replacedRecord.trashedURL, date: replacedEvent.date))
    inboxes.setMark(
      scanRow.id,
      .filed(
        newURL: replacing.movedURL, destinationPath: notenPath, date: replacing.event.date,
        documentID: replacing.event.documentID))

    #expect(staleEntry.url == replacing.movedURL)
    #expect(history.inboxRowID(for: staleEntry) == nil)

    await history.returnToInbox(staleEntry)

    #expect(exists(replacing.movedURL))
    #expect(!exists(scan))
    #expect(!exists(invoice))
    #expect(
      history.alert?.message
        == FilingMessages.text(for: .fileChangedSinceFiling(replacing.movedURL)))
    #expect(inboxes.row(for: scanRow.id)?.mark?.filedDocumentID == replacing.event.documentID)
    #expect(history.returnAction(for: try #require(history.entries.first)) == nil)
  }
}
