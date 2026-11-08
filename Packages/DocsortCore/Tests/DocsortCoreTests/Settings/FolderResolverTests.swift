import Foundation
import Testing

@testable import DocsortCore

@Suite("FolderResolver")
struct FolderResolverTests {
  let directory: TemporaryDirectory
  let root: URL

  init() throws {
    directory = try TemporaryDirectory()
    root = directory.url.resolvingSymlinksInPath()
  }

  func folder(_ relativePath: String) throws -> URL {
    try directory.createFolder(relativePath)
    return root.appending(path: relativePath, directoryHint: .isDirectory)
  }

  static func reference(_ name: String, at url: URL) -> FolderReference {
    FolderReference(bookmark: Data("bookmark:\(name)".utf8), url: url)
  }

  static func settings(archiveRoot: FolderReference?, inboxes: [FolderReference] = [])
    -> FolderSettings
  {
    var settings = FolderSettings(archiveRoot: archiveRoot)
    for inbox in inboxes {
      settings.addInbox(inbox)
    }
    return settings
  }

  @Test("a folder that resolves and exists is available, and nothing changes")
  func available() throws {
    let archive = try folder("Drive")
    let reference = Self.reference("archive", at: archive)
    let coding = FakeBookmarkCoding(resolutions: [
      reference.bookmark: .resolves(archive, isStale: false)
    ])
    let access = RecordingScopeAccess()
    let settings = Self.settings(archiveRoot: reference)

    let session = FolderResolver(bookmarks: coding, access: access).resolve(settings)

    #expect(
      session.archiveRoot
        == ResolvedFolder(reference: reference, url: archive, availability: .available))
    #expect(session.settings == settings)
    #expect(!session.settingsChanged)
    #expect(access.started == [archive])
  }

  @Test("each inbox is resolved in order, alongside its inbox")
  func inboxes() throws {
    let scans = try folder("Inbox/Scans")
    let downloads = try folder("Inbox/Downloads")
    let scansReference = Self.reference("scans", at: scans)
    let downloadsReference = Self.reference("downloads", at: downloads)
    let coding = FakeBookmarkCoding(resolutions: [
      scansReference.bookmark: .resolves(scans, isStale: false),
      downloadsReference.bookmark: .resolves(downloads, isStale: false),
    ])
    let settings = Self.settings(
      archiveRoot: nil, inboxes: [scansReference, downloadsReference])

    let session = FolderResolver(bookmarks: coding, access: RecordingScopeAccess())
      .resolve(settings)

    #expect(session.archiveRoot == nil)
    #expect(session.inboxes.map(\.inbox) == settings.inboxes)
    #expect(session.inboxes.map(\.folder.url) == [scans, downloads])
    #expect(session.inboxes.map(\.folder.availability) == [.available, .available])
  }

  @Test("a stale bookmark is renewed, stored and reported as available")
  func staleRenewed() throws {
    let archive = try folder("Drive")
    let reference = Self.reference("archive", at: archive)
    let coding = FakeBookmarkCoding(resolutions: [
      reference.bookmark: .resolves(archive, isStale: true)
    ])

    let session = FolderResolver(bookmarks: coding, access: RecordingScopeAccess())
      .resolve(Self.settings(archiveRoot: reference))

    let renewed = FolderReference(
      bookmark: FakeBookmarkCoding.renewedBookmark(for: archive), url: archive)
    #expect(
      session.archiveRoot
        == ResolvedFolder(reference: renewed, url: archive, availability: .available))
    #expect(session.settings.archiveRoot == renewed)
    #expect(session.settingsChanged)
  }

  @Test("a stale bookmark that cannot be renewed is stale but usable, and kept")
  func staleNotRenewed() throws {
    let archive = try folder("Drive")
    let reference = Self.reference("archive", at: archive)
    let coding = FakeBookmarkCoding(
      resolutions: [reference.bookmark: .resolves(archive, isStale: true)], renewal: .fails)
    let access = RecordingScopeAccess()

    let session = FolderResolver(bookmarks: coding, access: access)
      .resolve(Self.settings(archiveRoot: reference))

    #expect(
      session.archiveRoot
        == ResolvedFolder(reference: reference, url: archive, availability: .stale))
    #expect(!session.settingsChanged)
    #expect(access.started == [archive])
  }

  @Test(
    "a bookmark whose folder no longer exists is missing",
    arguments: [
      CocoaError(.fileNoSuchFile) as any Error,
      CocoaError(.fileReadNoSuchFile),
      POSIXError(.ENOENT),
    ])
  func resolutionNotFound(error: any Error) throws {
    let reference = FolderReference(
      bookmark: Data("bookmark".utf8), lastKnownPath: "/Users/me/Drive/Inbox/Scans")
    let coding = FakeBookmarkCoding(resolutions: [reference.bookmark: .fails(error)])
    let access = RecordingScopeAccess()

    let session = FolderResolver(bookmarks: coding, access: access)
      .resolve(Self.settings(archiveRoot: nil, inboxes: [reference]))

    let inbox = try #require(session.inboxes.first)
    #expect(inbox.folder == ResolvedFolder(reference: reference, url: nil, availability: .missing))
    #expect(inbox.inbox.folder.lastKnownPath == "/Users/me/Drive/Inbox/Scans")
    #expect(!session.settingsChanged)
    #expect(access.started.isEmpty)
  }

  @Test("other resolution errors make the folder unreachable with the error's description")
  func resolutionFailsOtherwise() throws {
    let reference = FolderReference(bookmark: Data("bookmark".utf8), lastKnownPath: "/Volumes/NAS")
    let error = CocoaError(.fileReadCorruptFile)
    let coding = FakeBookmarkCoding(resolutions: [reference.bookmark: .fails(error)])

    let session = FolderResolver(bookmarks: coding, access: RecordingScopeAccess())
      .resolve(Self.settings(archiveRoot: reference))

    #expect(
      session.archiveRoot
        == ResolvedFolder(
          reference: reference, url: nil,
          availability: .unreachable(reason: error.localizedDescription)))
  }

  @Test("a resolved folder that is gone from disk is missing, and its access is stopped")
  func resolvedButMissingOnDisk() throws {
    let gone = root.appending(path: "Gone", directoryHint: .isDirectory)
    let reference = Self.reference("gone", at: gone)
    let coding = FakeBookmarkCoding(resolutions: [
      reference.bookmark: .resolves(gone, isStale: false)
    ])
    let access = RecordingScopeAccess()

    let session = FolderResolver(bookmarks: coding, access: access)
      .resolve(Self.settings(archiveRoot: reference))

    #expect(
      session.archiveRoot == ResolvedFolder(reference: reference, url: nil, availability: .missing))
    #expect(access.started == [gone])
    #expect(access.stopped == [gone])
  }

  @Test("a resolved item that is a file is unreachable, and its access is stopped")
  func resolvedToFile() throws {
    let file = try directory.createFile("Scans.pdf").resolvingSymlinksInPath()
    let reference = Self.reference("file", at: file)
    let coding = FakeBookmarkCoding(resolutions: [
      reference.bookmark: .resolves(file, isStale: false)
    ])
    let access = RecordingScopeAccess()

    let session = FolderResolver(bookmarks: coding, access: access)
      .resolve(Self.settings(archiveRoot: reference))

    let resolved = try #require(session.archiveRoot)
    #expect(resolved.url == nil)
    guard case .unreachable = resolved.availability else {
      Issue.record("expected unreachable, got \(resolved.availability)")
      return
    }
    #expect(access.stopped == [file])
  }

  @Test("a folder whose security scope is refused is unreachable and never stopped")
  func accessRefused() throws {
    let archive = try folder("Drive")
    let reference = Self.reference("archive", at: archive)
    let coding = FakeBookmarkCoding(resolutions: [
      reference.bookmark: .resolves(archive, isStale: false)
    ])
    let access = RecordingScopeAccess(refusing: [archive])

    let session = FolderResolver(bookmarks: coding, access: access)
      .resolve(Self.settings(archiveRoot: reference))
    session.end()

    let resolved = try #require(session.archiveRoot)
    #expect(resolved.url == nil)
    guard case .unreachable = resolved.availability else {
      Issue.record("expected unreachable, got \(resolved.availability)")
      return
    }
    #expect(access.stopped.isEmpty)
  }

  @Test("the last known path follows the folder when it resolves elsewhere")
  func lastKnownPathFollows() throws {
    let moved = try folder("Inbox/Renamed")
    let reference = FolderReference(
      bookmark: Data("bookmark".utf8),
      lastKnownPath: root.appending(path: "Inbox/Scans").path(percentEncoded: false))
    let coding = FakeBookmarkCoding(resolutions: [
      reference.bookmark: .resolves(moved, isStale: false)
    ])
    let settings = Self.settings(archiveRoot: nil, inboxes: [reference])

    let session = FolderResolver(bookmarks: coding, access: RecordingScopeAccess())
      .resolve(settings)

    let inbox = try #require(session.inboxes.first)
    #expect(inbox.folder.reference.lastKnownPath == FolderReference.path(of: moved))
    #expect(inbox.folder.reference.folderName == "Renamed")
    #expect(inbox.inbox.folder == inbox.folder.reference)
    #expect(session.settings.inboxes.first?.folder.lastKnownPath == FolderReference.path(of: moved))
    #expect(session.settings.inboxes.first?.id == settings.inboxes.first?.id)
    #expect(session.settingsChanged)
  }

  @Test("releasing the session ends it")
  func releaseEnds() throws {
    let archive = try folder("Drive")
    let reference = Self.reference("archive", at: archive)
    let coding = FakeBookmarkCoding(resolutions: [
      reference.bookmark: .resolves(archive, isStale: false)
    ])
    let access = RecordingScopeAccess()

    do {
      let session = FolderResolver(bookmarks: coding, access: access)
        .resolve(Self.settings(archiveRoot: reference))
      #expect(session.archiveRoot?.availability == .available)
    }

    #expect(access.stopped == [archive])
  }

  @Test("makeReference stores the bookmark and the folder's path")
  func makeReference() throws {
    let scans = try folder("Inbox/Scans")

    let reference = try FolderResolver(
      bookmarks: FakeBookmarkCoding(), access: RecordingScopeAccess()
    )
    .makeReference(for: scans)

    #expect(reference.bookmark == FakeBookmarkCoding.renewedBookmark(for: scans))
    #expect(
      reference.lastKnownPath == root.appending(path: "Inbox/Scans").path(percentEncoded: false))
    #expect(reference.folderName == "Scans")
  }

  @Test("makeReference reports the folder when the bookmark cannot be created")
  func makeReferenceFails() throws {
    let scans = try folder("Inbox/Scans")
    let resolver = FolderResolver(
      bookmarks: FakeBookmarkCoding(renewal: .fails), access: RecordingScopeAccess())

    let error = try #require(throws: BookmarkCreationError.self) {
      try resolver.makeReference(for: scans)
    }

    #expect(error.url == scans)
    #expect(error.underlying is FakeBookmarkCoding.RenewalRefused)
  }

  @Test("end stops exactly the scopes that were started, once")
  func endStopsStartedScopes() throws {
    let archive = try folder("Drive")
    let scans = try folder("Inbox/Scans")
    let refused = try folder("Inbox/Refused")
    let gone = root.appending(path: "Inbox/Gone", directoryHint: .isDirectory)
    let references = [
      "archive": Self.reference("archive", at: archive),
      "scans": Self.reference("scans", at: scans),
      "refused": Self.reference("refused", at: refused),
      "gone": Self.reference("gone", at: gone),
    ]
    let coding = FakeBookmarkCoding(resolutions: [
      Data("bookmark:archive".utf8): .resolves(archive, isStale: false),
      Data("bookmark:scans".utf8): .resolves(scans, isStale: false),
      Data("bookmark:refused".utf8): .resolves(refused, isStale: false),
      Data("bookmark:gone".utf8): .resolves(gone, isStale: false),
    ])
    let access = RecordingScopeAccess(refusing: [refused])
    let settings = Self.settings(
      archiveRoot: references["archive"],
      inboxes: [references["scans"], references["refused"], references["gone"]].compactMap { $0 })

    let session = FolderResolver(bookmarks: coding, access: access).resolve(settings)
    #expect(access.stopped == [gone])

    session.end()
    session.end()

    #expect(access.started == [archive, scans, gone])
    #expect(access.stopped == [gone, archive, scans])
  }
}
