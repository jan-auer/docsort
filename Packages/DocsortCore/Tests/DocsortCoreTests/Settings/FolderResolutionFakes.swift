import Foundation
import Synchronization

@testable import DocsortCore

/// Bookmark coding that resolves each bookmark as configured and renews bookmarks as `renewal` says.
struct FakeBookmarkCoding: BookmarkCoding {
  enum Resolution: Sendable {
    case resolves(URL, isStale: Bool)
    case fails(any Error)
  }

  enum Renewal: Sendable {
    case succeeds
    case fails
  }

  struct RenewalRefused: Error {}
  struct UnknownBookmark: Error {}

  var resolutions: [Data: Resolution] = [:]
  var renewal = Renewal.succeeds

  /// The bookmark data `makeBookmark(for:)` returns for `url`.
  static func renewedBookmark(for url: URL) -> Data {
    Data("renewed:\(url.path(percentEncoded: false))".utf8)
  }

  func makeBookmark(for url: URL) throws -> Data {
    switch renewal {
    case .succeeds: Self.renewedBookmark(for: url)
    case .fails: throw RenewalRefused()
    }
  }

  func resolveBookmark(_ data: Data) throws -> ResolvedBookmark {
    switch resolutions[data] {
    case .resolves(let url, let isStale): ResolvedBookmark(url: url, isStale: isStale)
    case .fails(let error): throw error
    case nil: throw UnknownBookmark()
    }
  }
}

/// Security scope access that records every start and stop and refuses the URLs in `refused`.
final class RecordingScopeAccess: SecurityScopeAccess {
  private let refused: Set<URL>
  private let log = Mutex<(started: [URL], stopped: [URL])>(([], []))

  init(refusing refused: Set<URL> = []) {
    self.refused = refused
  }

  var started: [URL] { log.withLock { $0.started } }
  var stopped: [URL] { log.withLock { $0.stopped } }

  func startAccessing(_ url: URL) -> Bool {
    guard !refused.contains(url) else {
      return false
    }
    log.withLock { $0.started.append(url) }
    return true
  }

  func stopAccessing(_ url: URL) {
    log.withLock { $0.stopped.append(url) }
  }
}
