import Foundation

/// Creates folder references from picked folders and resolves the configured folders at launch.
///
/// Resolution never fails as a whole: each folder is reported as available, stale, missing or unreachable, and a
/// folder that cannot be resolved keeps its reference, including its last known path.
public struct FolderResolver: Sendable {
  private let bookmarks: any BookmarkCoding
  private let access: any SecurityScopeAccess

  /// A resolver using `bookmarks` to create and resolve bookmarks and `access` to start security scopes.
  public init(
    bookmarks: any BookmarkCoding = SecurityScopedBookmarkCoding(),
    access: any SecurityScopeAccess = SystemSecurityScopeAccess()
  ) {
    self.bookmarks = bookmarks
    self.access = access
  }

  /// A reference to the folder at `url`, which the app must be able to access (for example from the open panel).
  public func makeReference(for url: URL) throws(BookmarkCreationError) -> FolderReference {
    do {
      return FolderReference(bookmark: try bookmarks.makeBookmark(for: url), url: url)
    } catch {
      throw BookmarkCreationError(url: url, underlying: error)
    }
  }

  /// Resolves the archive root and every inbox in `settings`, starting the security scope of each usable folder.
  ///
  /// Stale bookmarks of usable folders are renewed, and last known paths follow folders that moved; the returned
  /// session's `settings` carry those changes. End the session to stop the scopes it started.
  public func resolve(_ settings: FolderSettings) -> FolderAccessSession {
    var activeScopes: [URL] = []
    let archiveRoot = settings.archiveRoot.map { resolveFolder($0, activeScopes: &activeScopes) }
    let inboxes = settings.inboxes.map { inbox in
      let folder = resolveFolder(inbox.folder, activeScopes: &activeScopes)
      var resolvedInbox = inbox
      resolvedInbox.folder = folder.reference
      return ResolvedInbox(inbox: resolvedInbox, folder: folder)
    }
    let resolvedSettings = FolderSettings(
      archiveRoot: archiveRoot?.reference, inboxes: inboxes.map(\.inbox))
    return FolderAccessSession(
      settings: resolvedSettings,
      settingsChanged: resolvedSettings != settings,
      archiveRoot: archiveRoot,
      inboxes: inboxes,
      activeScopes: activeScopes,
      access: access)
  }

  /// Resolves one folder; when it is usable, its URL is appended to `activeScopes` with its scope started.
  private func resolveFolder(_ reference: FolderReference, activeScopes: inout [URL])
    -> ResolvedFolder
  {
    let resolved: ResolvedBookmark
    do {
      resolved = try bookmarks.resolveBookmark(reference.bookmark)
    } catch {
      let availability: FolderAvailability =
        Self.isNoSuchFile(error) ? .missing : .unreachable(reason: error.localizedDescription)
      return ResolvedFolder(reference: reference, url: nil, availability: availability)
    }

    let url = resolved.url
    var updatedReference = reference
    updatedReference.lastKnownPath = FileLocation.path(of: url)

    guard access.startAccessing(url) else {
      return ResolvedFolder(
        reference: updatedReference, url: nil,
        availability: .unreachable(reason: "Access to the folder was refused."))
    }
    if let problem = Self.folderProblem(at: url) {
      access.stopAccessing(url)
      return ResolvedFolder(reference: updatedReference, url: nil, availability: problem)
    }
    activeScopes.append(url)

    guard resolved.isStale else {
      return ResolvedFolder(reference: updatedReference, url: url, availability: .available)
    }
    do {
      updatedReference.bookmark = try bookmarks.makeBookmark(for: url)
      return ResolvedFolder(reference: updatedReference, url: url, availability: .available)
    } catch {
      // The folder is usable now; keeping the old bookmark and reporting `.stale` is the documented outcome when
      // renewal fails, and the next launch tries again.
      return ResolvedFolder(reference: updatedReference, url: url, availability: .stale)
    }
  }

  /// Why the item at `url` is not a usable folder, or `nil` when it is one.
  private static func folderProblem(at url: URL) -> FolderAvailability? {
    let isDirectory: Bool?
    do {
      isDirectory = try url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory
    } catch {
      return isNoSuchFile(error) ? .missing : .unreachable(reason: error.localizedDescription)
    }
    guard isDirectory == true else {
      return .unreachable(reason: "“\(url.lastPathComponent)” is not a folder.")
    }
    return nil
  }

  /// Whether `error` says the item does not exist.
  private static func isNoSuchFile(_ error: any Error) -> Bool {
    let nsError = error as NSError
    switch nsError.domain {
    case NSCocoaErrorDomain:
      return nsError.code == CocoaError.fileNoSuchFile.rawValue
        || nsError.code == CocoaError.fileReadNoSuchFile.rawValue
    case NSPOSIXErrorDomain:
      return nsError.code == Int(ENOENT)
    default:
      return false
    }
  }
}

/// Bookmark data could not be created for a folder the user picked.
public struct BookmarkCreationError: Error, CustomStringConvertible {
  /// The folder the bookmark was for.
  public let url: URL
  /// The system's error.
  public let underlying: any Error

  /// A message naming the folder and the cause, for logs.
  public var description: String {
    "Could not create a bookmark for \(url.path(percentEncoded: false)): \(underlying)"
  }
}
