import Foundation

/// The URL a bookmark resolved to, and whether the bookmark should be recreated.
public struct ResolvedBookmark: Sendable {
  /// The folder's current location.
  public let url: URL
  /// True when the system reports the bookmark data as stale; it still resolved, but should be replaced with new
  /// bookmark data for `url`.
  public let isStale: Bool

  /// A resolution to `url`, stale or not.
  public init(url: URL, isStale: Bool) {
    self.url = url
    self.isStale = isStale
  }
}

/// Creates and resolves bookmark data for folders.
public protocol BookmarkCoding: Sendable {
  /// Bookmark data for the folder at `url`.
  func makeBookmark(for url: URL) throws -> Data
  /// The folder `data` refers to; throws when it cannot be found or the data is invalid.
  func resolveBookmark(_ data: Data) throws -> ResolvedBookmark
}

/// Security-scoped bookmarks, as the sandboxed app needs for folders the user picked.
///
/// Bookmarks are created with `.withSecurityScope` (the app has the `com.apple.security.files.bookmarks.app-scope`
/// entitlement) and resolved with `.withSecurityScope`, `.withoutUI` and `.withoutMounting`, so resolution at launch
/// never shows UI and never mounts a volume. Access to a resolved URL must be started with `SecurityScopeAccess`.
public struct SecurityScopedBookmarkCoding: BookmarkCoding {
  /// The system's security-scoped bookmark coding.
  public init() {}

  /// Security-scoped bookmark data for the folder at `url`.
  ///
  /// The process must have access to `url`: it came from the open panel, or its security scope has been started.
  public func makeBookmark(for url: URL) throws -> Data {
    try url.bookmarkData(
      options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)
  }

  /// The folder `data` refers to, without UI and without mounting volumes.
  public func resolveBookmark(_ data: Data) throws -> ResolvedBookmark {
    var isStale = false
    let url = try URL(
      resolvingBookmarkData: data,
      options: [.withSecurityScope, .withoutUI, .withoutMounting],
      relativeTo: nil,
      bookmarkDataIsStale: &isStale)
    return ResolvedBookmark(url: url, isStale: isStale)
  }
}
