import DocsortCore
import Foundation
import Testing

@testable import Docsort

@MainActor
@Suite("ArchiveLibrary")
struct ArchiveLibraryTests {
  /// Creates `Hund Fritzi/Tierarzt` and `Reisen` in the archive, next to the inboxes in `_Neu`, and a symbolic link
  /// `Gemeinsam` pointing outside the archive.
  private func makeArchive(in environment: TestFolderEnvironment) throws {
    for folder in ["Hund Fritzi/Tierarzt", "Reisen"] {
      try FileManager.default.createDirectory(
        at: environment.archive.appending(path: folder), withIntermediateDirectories: true)
    }
    let outside = environment.root.appending(path: "Gemeinsam", directoryHint: .isDirectory)
    try FileManager.default.createDirectory(at: outside, withIntermediateDirectories: true)
    try FileManager.default.createSymbolicLink(
      at: environment.archive.appending(path: "Gemeinsam"), withDestinationURL: outside)
  }

  @Test("The index leaves out the inboxes and reports symbolic links")
  func indexesWithoutInboxes() async throws {
    let environment = try TestFolderEnvironment()
    defer { environment.remove() }
    try makeArchive(in: environment)
    let library = ArchiveLibrary()

    library.update(
      to: ArchiveIndexRequest(
        root: environment.archive, excludedFolders: [environment.scanner, environment.webDownloads])
    )
    #expect(library.status == .indexing)
    await library.waitForIndexing()

    let index = try #require(library.index)
    #expect(index.folders == ["_Neu", "Hund Fritzi", "Hund Fritzi/Tierarzt", "Reisen"])
    guard case .ready(let folderCount, let problems) = library.status else {
      Issue.record("Expected a ready index, got \(library.status)")
      return
    }
    #expect(folderCount == 4)
    #expect(problems.map(\.kind) == [.symbolicLink])
    #expect(problems.first?.url.lastPathComponent == "Gemeinsam")
  }

  @Test("A rebuild keeps the old index in use until the new one is ready")
  func rebuildKeepsTheOldIndex() async throws {
    let environment = try TestFolderEnvironment()
    defer { environment.remove() }
    try makeArchive(in: environment)
    let library = ArchiveLibrary()
    library.update(
      to: ArchiveIndexRequest(
        root: environment.archive, excludedFolders: [environment.scanner, environment.webDownloads])
    )
    await library.waitForIndexing()
    let before = try #require(library.index)

    try FileManager.default.createDirectory(
      at: environment.archive.appending(path: "Reisen/2033-11 Besuch Westerholm"),
      withIntermediateDirectories: true)
    library.rebuild()
    #expect(library.index?.folders == before.folders)
    #expect(library.status != .indexing)
    await library.waitForIndexing()

    #expect(library.index?.contains("Reisen/2033-11 Besuch Westerholm") == true)
  }

  @Test("A missing archive root fails with a reason, and no request clears the index")
  func missingRootFails() async throws {
    let environment = try TestFolderEnvironment()
    defer { environment.remove() }
    let library = ArchiveLibrary()

    library.update(
      to: ArchiveIndexRequest(
        root: environment.root.appending(path: "Nirgends"), excludedFolders: []))
    await library.waitForIndexing()
    #expect(library.status == .failed(reason: "The archive folder was not found."))

    library.update(to: nil)
    #expect(library.status == .unavailable)
    #expect(library.index == nil)
  }

  @Test("A superseded build is ignored")
  func supersededBuildIsIgnored() async throws {
    let environment = try TestFolderEnvironment()
    defer { environment.remove() }
    try makeArchive(in: environment)
    let library = ArchiveLibrary()

    library.update(to: ArchiveIndexRequest(root: environment.archive, excludedFolders: []))
    library.update(
      to: ArchiveIndexRequest(
        root: environment.archive.appending(path: "Hund Fritzi"), excludedFolders: []))
    await library.waitForIndexing()

    #expect(library.index?.folders == ["Tierarzt"])
    #expect(library.status == .ready(folderCount: 1, problems: []))
  }

  @Test("The library follows the folder library's archive root and inboxes")
  func followsFolderLibrary() async throws {
    let environment = try TestFolderEnvironment()
    defer { environment.remove() }
    try makeArchive(in: environment)
    let folders = FolderLibrary(environment: environment.appEnvironment)
    let library = ArchiveLibrary(folders: folders)

    folders.setArchiveRoot(to: environment.archive)
    folders.addInbox(folder: environment.scanner)
    folders.addInbox(folder: environment.webDownloads)

    // Observations delivers the folder changes asynchronously: wait until an index without the inboxes is ready.
    var attempts = 0
    while library.index?.folders.contains("_Neu/Scanner") != false, attempts < 200 {
      attempts += 1
      await Task.yield()
      await library.waitForIndexing()
    }
    #expect(library.index?.folders == ["_Neu", "Hund Fritzi", "Hund Fritzi/Tierarzt", "Reisen"])
  }
}
