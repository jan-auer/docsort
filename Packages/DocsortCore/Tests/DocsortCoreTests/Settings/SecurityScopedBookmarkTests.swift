import Foundation
import Testing

@testable import DocsortCore

/// Runs the system's security-scoped bookmarks against temporary folders.
///
/// `swift test` runs unsandboxed; there, `.withSecurityScope` bookmarks are created and resolved like in the
/// sandboxed app, and starting their scope succeeds.
@Suite("SecurityScopedBookmarks")
struct SecurityScopedBookmarkTests {
  let directory: TemporaryDirectory
  let resolver = FolderResolver()

  init() throws {
    directory = try TemporaryDirectory()
  }

  func folderPath(_ relativePath: String) -> String {
    FileLocation.path(of: directory.url.appending(path: relativePath).resolvingSymlinksInPath())
  }

  @Test("a bookmark resolves back to its folder, available and unchanged")
  func roundTrip() throws {
    let scans = try directory.createFolder("Inbox/Scans")
    let reference = try resolver.makeReference(for: scans)
    var settings = FolderSettings.empty
    settings.addInbox(reference)

    let session = resolver.resolve(settings)
    defer { session.end() }

    let inbox = try #require(session.inboxes.first)
    #expect(inbox.folder.availability == .available)
    #expect(try #require(inbox.folder.url).path(percentEncoded: false).hasSuffix("/Inbox/Scans/"))
    #expect(inbox.folder.reference.folderName == "Scans")
  }

  @Test("a renamed folder resolves to its new path, which becomes the last known path")
  func renamed() throws {
    let scans = try directory.createFolder("Inbox/Scans")
    let reference = try resolver.makeReference(for: scans)
    try FileManager.default.moveItem(at: scans, to: directory.url.appending(path: "Inbox/Renamed"))

    let session = resolver.resolve(FolderSettings(archiveRoot: reference))
    defer { session.end() }

    let archiveRoot = try #require(session.archiveRoot)
    #expect(archiveRoot.availability == .available)
    #expect(archiveRoot.reference.lastKnownPath == folderPath("Inbox/Renamed"))
    #expect(archiveRoot.reference.folderName == "Renamed")
    #expect(archiveRoot.reference.bookmark != reference.bookmark)
    #expect(session.settings.archiveRoot == archiveRoot.reference)
    #expect(session.settingsChanged)
  }

  @Test("a renewed bookmark resolves without being stale")
  func renewedBookmarkIsFresh() throws {
    let scans = try directory.createFolder("Inbox/Scans")
    let reference = try resolver.makeReference(for: scans)
    try FileManager.default.moveItem(at: scans, to: directory.url.appending(path: "Inbox/Renamed"))
    let first = resolver.resolve(FolderSettings(archiveRoot: reference))
    first.end()

    let second = resolver.resolve(first.settings)
    defer { second.end() }

    #expect(second.archiveRoot?.availability == .available)
    #expect(!second.settingsChanged)
  }

  @Test("a deleted folder is missing and keeps its last known path")
  func deleted() throws {
    let scans = try directory.createFolder("Inbox/Scans")
    let reference = try resolver.makeReference(for: scans)
    try FileManager.default.removeItem(at: scans)

    let session = resolver.resolve(FolderSettings(archiveRoot: reference))
    defer { session.end() }

    #expect(
      session.archiveRoot == ResolvedFolder(reference: reference, url: nil, availability: .missing))
    #expect(!session.settingsChanged)
  }

  @Test("bookmark data that is not a bookmark makes the folder unreachable")
  func invalidData() throws {
    let reference = FolderReference(bookmark: Data("garbage".utf8), lastKnownPath: "/Drive")

    let session = resolver.resolve(FolderSettings(archiveRoot: reference))
    defer { session.end() }

    let archiveRoot = try #require(session.archiveRoot)
    #expect(archiveRoot.url == nil)
    guard case .unreachable(let reason) = archiveRoot.availability else {
      Issue.record("expected unreachable, got \(archiveRoot.availability)")
      return
    }
    #expect(!reason.isEmpty)
  }
}
