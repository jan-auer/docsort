import DocsortCore
import Foundation
import Testing

@testable import Docsort

@Suite("FilingService: archive files")
struct FilingServiceArchiveTests {
  private let notenPath = "Musik Margit/Noten & Bücher"

  private func makeService(_ environment: TestFolderEnvironment) -> FilingService {
    FilingService(
      historyURL: environment.root.appending(path: "FilingHistory.json"),
      recentsPreference: RecentDestinations.preference(in: environment.defaults),
      fileOperations: FileOperations(
        trash: FixtureTrash(folder: environment.root.appending(path: "Trash"))))
  }

  private func exists(_ url: URL) -> Bool {
    FileManager.default.fileExists(atPath: url.path(percentEncoded: false))
  }

  @Test("Renaming an archive file is recorded, records no recent and can be undone")
  func renameArchiveFile() async throws {
    let environment = try TestFolderEnvironment()
    defer { environment.remove() }
    let folder = environment.archive.appending(path: notenPath)
    let sheet = try writeInboxFile(
      named: "2033-10-13 Notenhaus.pdf", in: folder, date: october2033(2))
    let service = makeService(environment)

    let outcome = try await service.rename(sheet, to: "2033-10-13 Notenhaus Allegretto.pdf")

    #expect(outcome.movedURL.lastPathComponent == "2033-10-13 Notenhaus Allegretto.pdf")
    #expect(outcome.movedURL.deletingLastPathComponent().lastPathComponent == "Noten & Bücher")
    #expect(exists(outcome.movedURL))
    #expect(!exists(sheet))
    #expect(outcome.status.recents.paths.isEmpty)
    #expect(await service.events().map(\.id) == [outcome.event.id])

    _ = try await service.undo(eventID: outcome.event.id)
    #expect(exists(sheet))
    #expect(!exists(outcome.movedURL))
  }

  @Test("Renaming to a taken name refuses with a conflict and changes nothing")
  func renameConflict() async throws {
    let environment = try TestFolderEnvironment()
    defer { environment.remove() }
    let folder = environment.archive.appending(path: notenPath)
    let sheet = try writeInboxFile(
      named: "2033-10-13 Notenhaus.pdf", in: folder, date: october2033(2))
    _ = try writeInboxFile(
      named: "2033-10-13 Notenhaus Allegretto alt.pdf", in: folder, date: october2033(3))
    let service = makeService(environment)

    await #expect(throws: FilingError.self) {
      try await service.rename(sheet, to: "2033-10-13 Notenhaus Allegretto alt.pdf")
    }
    #expect(exists(sheet))
    #expect(await service.events().isEmpty)
  }

  @Test("Renaming a filed file in the archive continues its document, so Move Back still works")
  func renameFiledFileKeepsMoveBack() async throws {
    let environment = try TestFolderEnvironment()
    defer { environment.remove() }
    let invoice = try writeInboxFile(
      named: "Rechnung_NA-33-08812.pdf", in: environment.webDownloads, date: october2033(13))
    let folder = environment.archive.appending(path: notenPath)
    let service = makeService(environment)
    let filed = try await service.file(
      invoice, into: folder, archivePath: notenPath,
      named: "2033-10-13 Notenhaus Allegretto.pdf", resolution: .refuse)

    let renamed = try await service.rename(
      filed.movedURL, to: "2033-10-13 Notenhaus Allegretto Advent.pdf")
    #expect(renamed.event.documentID == filed.event.documentID)

    let movedBack = try await service.moveBack(
      document: filed.event.documentID, at: renamed.movedURL, resolution: .refuse)
    #expect(movedBack.movedURL.path(percentEncoded: false) == invoice.path(percentEncoded: false))
  }
}
