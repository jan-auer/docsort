import DocsortCore
import Foundation
import Testing

@testable import Docsort

@MainActor
@Suite("FolderLibrary")
struct FolderLibraryTests {
  @Test("First launch: nothing is configured and nothing is stored")
  func firstLaunchIsUnconfigured() throws {
    let environment = try TestFolderEnvironment()
    defer { environment.remove() }

    let library = FolderLibrary(environment: environment.appEnvironment)

    #expect(library.archiveRoot == nil)
    #expect(library.inboxes.isEmpty)
    #expect(!library.areFoldersConfigured)
    #expect(library.archiveAvailability == .notChosen)
    #expect(library.settingsReadError == nil)
    #expect(library.isEditable)
    #expect(try environment.storedSettings() == nil)
  }

  @Test("Adding an archive and an inbox saves the settings and resolves them")
  func addingFoldersSavesAndResolves() throws {
    let environment = try TestFolderEnvironment()
    defer { environment.remove() }
    let library = FolderLibrary(environment: environment.appEnvironment)

    library.setArchiveRoot(to: environment.archive)
    #expect(!library.areFoldersConfigured)
    library.addInbox(folder: environment.scanner)

    #expect(library.areFoldersConfigured)
    #expect(library.archiveAvailability == .available)
    #expect(library.archiveRoot?.availability == .available)
    #expect(library.archiveRoot?.url != nil)
    #expect(library.inboxes.map(\.displayLabel) == ["Scanner"])
    #expect(library.inboxes.first?.availability == .available)
    #expect(library.inboxes.first?.url != nil)

    let stored = try #require(try environment.storedSettings())
    #expect(stored.archiveRoot?.lastKnownPath == FileLocation.path(of: environment.archive))
    #expect(
      stored.inboxes.map(\.folder.lastKnownPath) == [FileLocation.path(of: environment.scanner)])

    let relaunched = FolderLibrary(environment: environment.appEnvironment)
    #expect(relaunched.areFoldersConfigured)
    #expect(relaunched.inboxes.map(\.id) == library.inboxes.map(\.id))
  }

  @Test("An edit starts the new session's scopes before the old session's stop")
  func newScopesStartBeforeOldOnesStop() throws {
    let environment = try TestFolderEnvironment()
    defer { environment.remove() }
    let library = FolderLibrary(environment: environment.appEnvironment)
    library.setArchiveRoot(to: environment.archive)
    environment.access.clearEvents()

    library.addInbox(folder: environment.scanner)

    let archive = FileLocation.path(of: environment.archive)
    let scanner = FileLocation.path(of: environment.scanner)
    #expect(environment.access.events == [.start(archive), .start(scanner), .stop(archive)])
  }

  @Test(
    "Unreadable stored settings are reported, refuse edits and are never overwritten until reset")
  func corruptSettingsAreNeverOverwritten() throws {
    let environment = try TestFolderEnvironment()
    defer { environment.remove() }
    let corrupt = Data("not folder settings".utf8)
    environment.defaults.set(corrupt, forKey: "folderSettings")

    let library = FolderLibrary(environment: environment.appEnvironment)

    #expect(library.settingsReadError != nil)
    #expect(!library.isEditable)
    #expect(!library.areFoldersConfigured)

    library.setArchiveRoot(to: environment.archive)
    library.addInbox(folder: environment.scanner)

    #expect(library.archiveRoot == nil)
    #expect(library.inboxes.isEmpty)
    #expect(environment.defaults.data(forKey: "folderSettings") == corrupt)
    #expect(environment.access.events.isEmpty)

    library.resetFolderSettings()

    #expect(environment.defaults.object(forKey: "folderSettings") == nil)
    #expect(library.settingsReadError == nil)
    #expect(library.isEditable)
    library.setArchiveRoot(to: environment.archive)
    #expect(library.archiveRoot?.availability == .available)
  }

  @Test("Renewed stale bookmarks are saved at launch")
  func renewedBookmarksAreSaved() throws {
    let environment = try TestFolderEnvironment()
    defer { environment.remove() }
    let first = FolderLibrary(environment: environment.appEnvironment)
    first.setArchiveRoot(to: environment.archive)
    first.addInbox(folder: environment.scanner)
    let before = try #require(try environment.storedSettings())

    environment.bookmarks.setStale(true, forPath: FileLocation.path(of: environment.scanner))
    let relaunched = FolderLibrary(environment: environment.appEnvironment)

    let after = try #require(try environment.storedSettings())
    #expect(after.archiveRoot == before.archiveRoot)
    #expect(after.inboxes.first?.folder.bookmark != before.inboxes.first?.folder.bookmark)
    #expect(after.inboxes.first?.id == before.inboxes.first?.id)
    #expect(relaunched.inboxes.first?.availability == .available)
  }

  @Test("Reordering, relabelling and removing inboxes are saved")
  func inboxEditsPersist() throws {
    let environment = try TestFolderEnvironment()
    defer { environment.remove() }
    let library = FolderLibrary(environment: environment.appEnvironment)
    library.setArchiveRoot(to: environment.archive)
    library.addInbox(folder: environment.webDownloads)
    library.addInbox(folder: environment.scanner)

    library.moveInboxes(fromOffsets: [1], toOffset: 0)
    #expect(library.inboxes.map(\.displayLabel) == ["Scanner", "Web-Downloads"])

    let webDownloadsID = try #require(library.inboxes.last?.id)
    library.relabelInbox(id: webDownloadsID, to: "Downloads")
    #expect(library.inboxes.map(\.displayLabel) == ["Scanner", "Downloads"])

    var stored = try #require(try environment.storedSettings())
    #expect(stored.inboxes.map(\.displayLabel) == ["Scanner", "Downloads"])

    library.relabelInbox(id: webDownloadsID, to: "  ")
    #expect(library.inboxes.last?.displayLabel == "Web-Downloads")

    let scannerID = try #require(library.inboxes.first?.id)
    library.removeInbox(id: scannerID)
    #expect(library.inboxes.map(\.id) == [webDownloadsID])

    stored = try #require(try environment.storedSettings())
    #expect(stored.inboxes.map(\.id) == [webDownloadsID])
    #expect(stored.inboxes.first?.label == nil)
    #expect(FileManager.default.fileExists(atPath: environment.scanner.path(percentEncoded: false)))
  }

  @Test(
    "A missing inbox folder is reported, and choosing it again keeps the inbox's identity and label"
  )
  func missingInboxCanBeReplaced() throws {
    let environment = try TestFolderEnvironment()
    defer { environment.remove() }
    let library = FolderLibrary(environment: environment.appEnvironment)
    library.setArchiveRoot(to: environment.archive)
    library.addInbox(folder: environment.scanner)
    let id = try #require(library.inboxes.first?.id)
    library.relabelInbox(id: id, to: "Scans")

    let moved = environment.archive.appending(path: "_Neu/Scanner alt", directoryHint: .isDirectory)
    try FileManager.default.moveItem(at: environment.scanner, to: moved)
    let relaunched = FolderLibrary(environment: environment.appEnvironment)
    #expect(relaunched.inboxes.first?.availability == .missing)
    #expect(relaunched.inboxes.first?.url == nil)

    relaunched.replaceFolder(ofInbox: id, with: moved)

    #expect(relaunched.inboxes.map(\.id) == [id])
    #expect(relaunched.inboxes.first?.displayLabel == "Scans")
    #expect(relaunched.inboxes.first?.availability == .available)
    let stored = try #require(try environment.storedSettings())
    #expect(stored.inboxes.first?.folder.lastKnownPath == FileLocation.path(of: moved))
  }

  @Test("A missing archive root makes the archive unavailable, named by its path")
  func missingArchiveIsUnavailable() throws {
    let environment = try TestFolderEnvironment()
    defer { environment.remove() }
    let library = FolderLibrary(environment: environment.appEnvironment)
    library.setArchiveRoot(to: environment.archive)
    library.addInbox(folder: environment.root)
    try FileManager.default.removeItem(at: environment.archive)

    let relaunched = FolderLibrary(environment: environment.appEnvironment)

    #expect(relaunched.areFoldersConfigured)
    #expect(relaunched.archiveRoot?.availability == .missing)
    let displayPath = DisplayPath.abbreviating(FileLocation.path(of: environment.archive))
    #expect(relaunched.archiveAvailability == .unreachable(displayPath: displayPath))
  }
}
