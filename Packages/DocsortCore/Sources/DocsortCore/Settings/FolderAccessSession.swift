import Foundation
import Synchronization

/// The configured folders as resolved at launch, holding the security scopes that resolution started.
///
/// Keep the session for as long as the app uses the folders. `end()` stops every scope the session started; releasing
/// the session ends it too.
public final class FolderAccessSession: Sendable {
  /// The settings with renewed bookmarks and updated last known paths; persist them when `settingsChanged` is true.
  public let settings: FolderSettings
  /// True when `settings` differs from the settings that were resolved, so they should be saved.
  public let settingsChanged: Bool
  /// The archive root's resolution, or `nil` when no archive root is configured.
  public let archiveRoot: ResolvedFolder?
  /// Each inbox's resolution, in sidebar order.
  public let inboxes: [ResolvedInbox]

  private let access: any SecurityScopeAccess
  private let activeScopes: Mutex<[URL]>

  init(
    settings: FolderSettings,
    settingsChanged: Bool,
    archiveRoot: ResolvedFolder?,
    inboxes: [ResolvedInbox],
    activeScopes: [URL],
    access: any SecurityScopeAccess
  ) {
    self.settings = settings
    self.settingsChanged = settingsChanged
    self.archiveRoot = archiveRoot
    self.inboxes = inboxes
    self.access = access
    self.activeScopes = Mutex(activeScopes)
  }

  deinit {
    end()
  }

  /// Stops every security scope this session started, each exactly once; later calls do nothing.
  ///
  /// The folders' URLs may no longer be accessible afterwards.
  public func end() {
    let scopes = activeScopes.withLock { scopes in
      defer { scopes = [] }
      return scopes
    }
    for url in scopes {
      access.stopAccessing(url)
    }
  }
}
