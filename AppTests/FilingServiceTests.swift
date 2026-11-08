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

  @Test(
    "Move Back returns a renamed filed file to its inbox name, is recorded and records no recent")
  func moveBackAfterRename() async throws {
    let environment = try TestFolderEnvironment()
    defer { environment.remove() }
    let invoice = try writeInboxFile(
      named: "Rechnung_NA-33-08812.pdf", in: environment.webDownloads, date: october2033(13))
    let folder = environment.archive.appending(path: notenPath)
    let service = makeService(environment)
    let filed = try await service.file(
      invoice, into: folder, archivePath: notenPath,
      named: "2033-10-13 Notenhaus Allegretto.pdf", resolution: .refuse)
    let renamed = try await service.refile(
      document: filed.event.documentID, at: filed.movedURL, into: folder, archivePath: notenPath,
      named: "2033-10-13 Notenhaus Allegretto Advent.pdf", resolution: .refuse)
    #expect(renamed.event.documentID == filed.event.documentID)

    let movedBack = try await service.moveBack(
      document: filed.event.documentID, at: renamed.movedURL, resolution: .refuse)

    #expect(movedBack.movedURL.path(percentEncoded: false) == invoice.path(percentEncoded: false))
    #expect(FileManager.default.fileExists(atPath: invoice.path(percentEncoded: false)))
    #expect(
      !FileManager.default.fileExists(atPath: renamed.movedURL.path(percentEncoded: false)))
    #expect(movedBack.event.documentID == filed.event.documentID)
    #expect(movedBack.status.recents.paths == [notenPath])

    // The move back is in the saved history, so a later session can undo it.
    let reloaded = makeService(environment)
    #expect(
      await reloaded.events().map(\.id) == [filed.event.id, renamed.event.id, movedBack.event.id])
    let undo = try await reloaded.undo(eventID: movedBack.event.id)
    #expect(
      undo.restored.url.path(percentEncoded: false)
        == renamed.movedURL.path(percentEncoded: false))
  }

  @Test("Move Back into a taken inbox name throws a conflict; Keep Both then uses a numbered name")
  func moveBackConflictThenKeepBoth() async throws {
    let environment = try TestFolderEnvironment()
    defer { environment.remove() }
    let invoice = try writeInboxFile(
      named: "Rechnung_NA-33-08812.pdf", in: environment.webDownloads, date: october2033(13))
    let service = makeService(environment)
    let filed = try await service.file(
      invoice, into: environment.archive.appending(path: notenPath), archivePath: notenPath,
      named: "2033-10-13 Notenhaus Allegretto.pdf", resolution: .refuse)
    _ = try writeInboxFile(
      named: "Rechnung_NA-33-08812.pdf", in: environment.webDownloads, date: october2033(20))

    do {
      _ = try await service.moveBack(
        document: filed.event.documentID, at: filed.movedURL, resolution: .refuse)
      Issue.record("Expected a name conflict")
    } catch .fileOperation(.nameConflict(let existing)) {
      #expect(existing.lastPathComponent == "Rechnung_NA-33-08812.pdf")
    } catch {
      Issue.record("Expected a name conflict, got \(error)")
    }
    #expect(FileManager.default.fileExists(atPath: filed.movedURL.path(percentEncoded: false)))

    let movedBack = try await service.moveBack(
      document: filed.event.documentID, at: filed.movedURL, resolution: .keepBoth)
    #expect(movedBack.movedURL.lastPathComponent == "Rechnung_NA-33-08812 2.pdf")
    #expect(
      movedBack.movedURL.deletingLastPathComponent().path(percentEncoded: false)
        == environment.webDownloads.path(percentEncoded: false))
  }

  @Test("Move Back of a file the history doesn't know is refused")
  func moveBackWithoutHistory() async throws {
    let environment = try TestFolderEnvironment()
    defer { environment.remove() }
    let filedOutside = try writeInboxFile(
      named: "2033-10-13 Notenhaus Allegretto.pdf",
      in: environment.archive.appending(path: notenPath), date: october2033(13))
    let service = makeService(environment)

    do {
      _ = try await service.moveBack(document: UUID(), at: filedOutside, resolution: .refuse)
      Issue.record("Expected no history record")
    } catch .noHistoryRecord(let url) {
      #expect(url == filedOutside)
    } catch {
      Issue.record("Expected no history record, got \(error)")
    }
    #expect(FileManager.default.fileExists(atPath: filedOutside.path(percentEncoded: false)))
  }

  @Test(
    "After a Replace, Move Back and renaming of the replaced file are refused and leave the replacing file in place"
  )
  func replacedDocumentIsRefused() async throws {
    let environment = try TestFolderEnvironment()
    defer { environment.remove() }
    let invoice = try writeInboxFile(
      named: "Rechnung_NA-33-08812.pdf", in: environment.webDownloads, date: october2033(13))
    let scan = try writeInboxFile(
      named: "2033-10-11_Optik Klarblick.pdf", in: environment.scanner, date: october2033(11))
    let folder = environment.archive.appending(path: notenPath)
    let service = makeService(environment)
    let filedInvoice = try await service.file(
      invoice, into: folder, archivePath: notenPath,
      named: "2033-10-13 Notenhaus Allegretto.pdf", resolution: .refuse)
    let replacing = try await service.file(
      scan, into: folder, archivePath: notenPath, named: "2033-10-13 Notenhaus Allegretto.pdf",
      resolution: .replace)
    #expect(filedInvoice.replacedEvent == nil)
    let replacedEvent = try #require(replacing.replacedEvent)
    #expect(replacedEvent.documentID == filedInvoice.event.documentID)
    #expect(replacedEvent.causedBy == replacing.event.id)
    let archived = replacing.movedURL

    do {
      _ = try await service.moveBack(
        document: filedInvoice.event.documentID, at: archived, resolution: .refuse)
      Issue.record("Expected the Move Back to be refused")
    } catch .fileChangedSinceFiling(let url) {
      #expect(url == archived)
    } catch {
      Issue.record("Expected fileChangedSinceFiling, got \(error)")
    }
    do {
      _ = try await service.refile(
        document: filedInvoice.event.documentID, at: archived, into: folder,
        archivePath: notenPath, named: "2033-10-13 Notenhaus Allegretto Advent.pdf",
        resolution: .refuse)
      Issue.record("Expected the rename to be refused")
    } catch .fileChangedSinceFiling(let url) {
      #expect(url == archived)
    } catch {
      Issue.record("Expected fileChangedSinceFiling, got \(error)")
    }

    // The replacing scan stays filed; nothing came back to either inbox.
    #expect(FileManager.default.fileExists(atPath: archived.path(percentEncoded: false)))
    #expect(!FileManager.default.fileExists(atPath: scan.path(percentEncoded: false)))
    #expect(!FileManager.default.fileExists(atPath: invoice.path(percentEncoded: false)))
    #expect(
      !FileManager.default.fileExists(
        atPath: folder.appending(path: "2033-10-13 Notenhaus Allegretto Advent.pdf")
          .path(percentEncoded: false)))
    // The scan's own document can still be moved back.
    let movedBack = try await service.moveBack(
      document: replacing.event.documentID, at: archived, resolution: .refuse)
    #expect(movedBack.movedURL.path(percentEncoded: false) == scan.path(percentEncoded: false))
  }

  @Test("Move Back refuses when another item took the filed file's place outside the app")
  func moveBackRefusesSwappedFile() async throws {
    let environment = try TestFolderEnvironment()
    defer { environment.remove() }
    let invoice = try writeInboxFile(
      named: "Rechnung_NA-33-08812.pdf", in: environment.webDownloads, date: october2033(13))
    let folder = environment.archive.appending(path: notenPath)
    let service = makeService(environment)
    let filed = try await service.file(
      invoice, into: folder, archivePath: notenPath,
      named: "2033-10-13 Notenhaus Allegretto.pdf", resolution: .refuse)
    // Outside the app, the filed file is set aside and another one takes its name.
    let setAside = folder.appending(path: "2033-10-13 Notenhaus Allegretto alt.pdf")
    try FileManager.default.moveItem(at: filed.movedURL, to: setAside)
    _ = try writeInboxFile(
      named: filed.movedURL.lastPathComponent, in: folder, date: october2033(14))

    do {
      _ = try await service.moveBack(
        document: filed.event.documentID, at: filed.movedURL, resolution: .refuse)
      Issue.record("Expected the Move Back to be refused")
    } catch .fileOperation(.differentItem), .fileOperation(.sourceMissing) {
      // Refused: the item there is not the one filed.
    } catch {
      Issue.record("Expected differentItem or sourceMissing, got \(error)")
    }

    #expect(FileManager.default.fileExists(atPath: filed.movedURL.path(percentEncoded: false)))
    #expect(FileManager.default.fileExists(atPath: setAside.path(percentEncoded: false)))
    #expect(!FileManager.default.fileExists(atPath: invoice.path(percentEncoded: false)))
  }

  @Test("Put Back restores a trashed file, also in a later session")
  func putBackRestoresTrashedFile() async throws {
    let environment = try TestFolderEnvironment()
    defer { environment.remove() }
    let scan = try writeInboxFile(
      named: "2033-10-11_Optik Klarblick.pdf", in: environment.scanner, date: october2033(11))
    let trashed = try await makeService(environment).trash(scan)

    let reloaded = makeService(environment)
    let putBack = try await reloaded.putBack(trashed.record.trashedURL)

    #expect(putBack.eventID == trashed.event.id)
    #expect(putBack.restored.url.path(percentEncoded: false) == scan.path(percentEncoded: false))
    #expect(FileManager.default.fileExists(atPath: scan.path(percentEncoded: false)))
    #expect(
      !FileManager.default.fileExists(atPath: trashed.record.trashedURL.path(percentEncoded: false))
    )
    await #expect(throws: FilingError.self) {
      try await reloaded.putBack(trashed.record.trashedURL)
    }
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
