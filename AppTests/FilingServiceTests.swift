import DocsortCore
import Foundation
import Testing

@testable import Docsort

/// Writes an empty file `name` into `folder`, dated `date`, and returns its URL.
func writeInboxFile(named name: String, in folder: URL, date: Date) throws -> URL {
  try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
  let url = folder.appending(path: name, directoryHint: .notDirectory)
  try Data("%PDF-1.4 sample".utf8).write(to: url)
  try FileManager.default.setAttributes(
    [.modificationDate: date, .creationDate: date], ofItemAtPath: url.path(percentEncoded: false))
  return url
}

/// The date `day` October 2033 at 10:00 UTC.
func october2033(_ day: Int) -> Date {
  var calendar = Calendar(identifier: .gregorian)
  calendar.timeZone = .gmt
  return calendar.date(from: DateComponents(year: 2033, month: 10, day: day, hour: 10))!
}

@Suite("FilingService")
struct FilingServiceTests {
  /// A service on `environment`'s history file and defaults, trashing into a folder of the environment.
  private func makeService(
    _ environment: TestFolderEnvironment, historyURL: URL? = nil
  ) -> FilingService {
    FilingService(
      historyURL: historyURL ?? environment.root.appending(path: "FilingHistory.json"),
      recentsPreference: RecentDestinations.preference(in: environment.defaults),
      fileOperations: FileOperations(
        trash: FixtureTrash(folder: environment.root.appending(path: "Trash"))))
  }

  private let notenPath = "Musik Margit/Noten & Bücher"

  @Test("A move is recorded, and the history and recents survive a reload")
  func movePersistsHistoryAndRecents() async throws {
    let environment = try TestFolderEnvironment()
    defer { environment.remove() }
    let invoice = try writeInboxFile(
      named: "Rechnung_NA-33-08812.pdf", in: environment.webDownloads, date: october2033(13))
    let folder = environment.archive.appending(path: notenPath)

    let service = makeService(environment)
    let outcome = try await service.file(
      invoice, into: folder, archivePath: notenPath,
      named: "2033-10-13 Notenhaus Allegretto.pdf", resolution: .refuse)

    #expect(outcome.movedURL.lastPathComponent == "2033-10-13 Notenhaus Allegretto.pdf")
    #expect(FileManager.default.fileExists(atPath: outcome.movedURL.path(percentEncoded: false)))
    #expect(outcome.status.recents.paths == [notenPath])
    #expect(outcome.status.pendingSaveError == nil)

    let reloaded = makeService(environment)
    let status = await reloaded.status()
    #expect(status.historyAvailability == .available)
    #expect(status.recents.paths == [notenPath])
    let undo = try await reloaded.undo(eventID: outcome.event.id)
    #expect(undo.restored.url.lastPathComponent == "Rechnung_NA-33-08812.pdf")
    #expect(FileManager.default.fileExists(atPath: invoice.path(percentEncoded: false)))
  }

  @Test("A taken name throws a conflict; Keep Both then files under a numbered name")
  func conflictThenKeepBoth() async throws {
    let environment = try TestFolderEnvironment()
    defer { environment.remove() }
    let folder = environment.archive.appending(path: "Kommunikation/Ilmnet Internet/Rechnungen")
    _ = try writeInboxFile(
      named: "2033-09-04 Rechnung September.pdf", in: folder, date: october2033(1))
    let download = try writeInboxFile(
      named: "2033-09-04 Rechnung September.pdf", in: environment.webDownloads,
      date: october2033(4))
    let service = makeService(environment)

    await #expect(throws: FilingError.self) {
      try await service.file(
        download, into: folder, archivePath: "Kommunikation/Ilmnet Internet/Rechnungen",
        named: download.lastPathComponent, resolution: .refuse)
    }
    do {
      _ = try await service.file(
        download, into: folder, archivePath: "Kommunikation/Ilmnet Internet/Rechnungen",
        named: download.lastPathComponent, resolution: .refuse)
      Issue.record("Expected a name conflict")
    } catch .fileOperation(.nameConflict(let existing)) {
      #expect(existing.lastPathComponent == "2033-09-04 Rechnung September.pdf")
    } catch {
      Issue.record("Expected a name conflict, got \(error)")
    }

    let outcome = try await service.file(
      download, into: folder, archivePath: "Kommunikation/Ilmnet Internet/Rechnungen",
      named: download.lastPathComponent, resolution: .keepBoth)
    #expect(outcome.movedURL.lastPathComponent == "2033-09-04 Rechnung September 2.pdf")
  }

  @Test("A trashed file is put back by undo")
  func trashAndUndo() async throws {
    let environment = try TestFolderEnvironment()
    defer { environment.remove() }
    let scan = try writeInboxFile(
      named: "2033-10-11_Optik Klarblick.pdf", in: environment.scanner, date: october2033(11))
    let service = makeService(environment)

    let trashed = try await service.trash(scan)
    #expect(!FileManager.default.fileExists(atPath: scan.path(percentEncoded: false)))
    #expect(
      FileManager.default.fileExists(atPath: trashed.record.trashedURL.path(percentEncoded: false)))

    let undo = try await service.undo(eventID: trashed.event.id)
    #expect(undo.restored.url.path(percentEncoded: false) == scan.path(percentEncoded: false))
    #expect(FileManager.default.fileExists(atPath: scan.path(percentEncoded: false)))
  }

  @Test("A failed save keeps the move, reports the error and succeeds on retry")
  func failedSaveKeepsTheChange() async throws {
    let environment = try TestFolderEnvironment()
    defer { environment.remove() }
    let historyFolder = environment.root.appending(path: "History")
    let service = makeService(
      environment, historyURL: historyFolder.appending(path: "FilingHistory.json"))
    #expect(await service.status().historyAvailability == .available)
    // A file where the history's folder should be makes every save fail.
    try Data().write(to: historyFolder)
    let invoice = try writeInboxFile(
      named: "Rechnung_NA-33-08812.pdf", in: environment.webDownloads, date: october2033(13))

    let outcome = try await service.file(
      invoice, into: environment.archive.appending(path: notenPath), archivePath: notenPath,
      named: invoice.lastPathComponent, resolution: .refuse)

    #expect(FileManager.default.fileExists(atPath: outcome.movedURL.path(percentEncoded: false)))
    #expect(outcome.status.pendingSaveError != nil)

    try FileManager.default.removeItem(at: historyFolder)
    #expect(await service.retrySave().pendingSaveError == nil)
    #expect(await service.saveBeforeQuit())
  }

  @Test("An unreadable history refuses filing until a new history is started, and is set aside")
  func unreadableHistory() async throws {
    let environment = try TestFolderEnvironment()
    defer { environment.remove() }
    let historyURL = environment.root.appending(path: "FilingHistory.json")
    try Data("not a history".utf8).write(to: historyURL)
    let scan = try writeInboxFile(
      named: "2033-10-11_Optik Klarblick.pdf", in: environment.scanner, date: october2033(11))
    let service = makeService(environment)

    guard case .unreadable = await service.status().historyAvailability else {
      Issue.record("Expected an unreadable history")
      return
    }
    await #expect(throws: FilingError.self) { try await service.trash(scan) }
    #expect(FileManager.default.fileExists(atPath: scan.path(percentEncoded: false)))

    let status = try await service.startNewHistory()
    #expect(status.historyAvailability == .available)
    let setAside = try FileManager.default.contentsOfDirectory(atPath: environment.root.path())
      .filter { $0.hasPrefix("FilingHistory-unreadable-") && $0.hasSuffix(".json") }
    #expect(setAside.count == 1)
    _ = try await service.trash(scan)
    #expect(FileManager.default.fileExists(atPath: historyURL.path(percentEncoded: false)))
  }
}
