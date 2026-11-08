import DocsortCore
import Foundation
import Synchronization

@testable import Docsort

/// Bookmarks that are just the folder's path and a version number, so tests need no security-scoped bookmarks.
///
/// Every bookmark made gets a new version, so a renewed bookmark differs from the one it replaces. Bookmarks for
/// paths in `stalePaths` resolve as stale.
final class FakeBookmarks: BookmarkCoding {
  private let state = Mutex(State())

  private struct State {
    var version = 0
    var stalePaths: Set<String> = []
  }

  /// Makes bookmarks for the folder at `path` resolve as stale (`true`) or not.
  func setStale(_ isStale: Bool, forPath path: String) {
    state.withLock { state in
      if isStale {
        state.stalePaths.insert(path)
      } else {
        state.stalePaths.remove(path)
      }
    }
  }

  func makeBookmark(for url: URL) throws -> Data {
    let version = state.withLock { state in
      state.version += 1
      return state.version
    }
    return Data("\(version)|\(url.path(percentEncoded: false))".utf8)
  }

  func resolveBookmark(_ data: Data) throws -> ResolvedBookmark {
    let text = String(decoding: data, as: UTF8.self)
    guard let separator = text.firstIndex(of: "|") else {
      throw CocoaError(.fileReadCorruptFile)
    }
    let path = String(text[text.index(after: separator)...])
    let isStale = state.withLock { $0.stalePaths.contains(Self.standardised(path)) }
    return ResolvedBookmark(url: URL(filePath: path, directoryHint: .isDirectory), isStale: isStale)
  }

  /// `path` without a trailing slash, as `FolderReference.lastKnownPath` spells it.
  private static func standardised(_ path: String) -> String {
    path.count > 1 && path.hasSuffix("/") ? String(path.dropLast()) : path
  }
}

/// Security scope access that always succeeds and records every start and stop in order.
final class RecordingScopeAccess: SecurityScopeAccess {
  /// One call to the access, with the folder's path.
  enum Event: Equatable, CustomStringConvertible {
    case start(String)
    case stop(String)

    var description: String {
      switch self {
      case .start(let path): "start \(path)"
      case .stop(let path): "stop \(path)"
      }
    }
  }

  private let recorded = Mutex<[Event]>([])

  /// The calls so far, oldest first.
  var events: [Event] { recorded.withLock { $0 } }

  /// Forgets the calls so far.
  func clearEvents() {
    recorded.withLock { $0.removeAll() }
  }

  func startAccessing(_ url: URL) -> Bool {
    recorded.withLock { $0.append(.start(Self.path(of: url))) }
    return true
  }

  func stopAccessing(_ url: URL) {
    recorded.withLock { $0.append(.stop(Self.path(of: url))) }
  }

  private static func path(of url: URL) -> String {
    let path = url.standardizedFileURL.path(percentEncoded: false)
    return path.count > 1 && path.hasSuffix("/") ? String(path.dropLast()) : path
  }
}

/// A throwaway environment for one test: its own `UserDefaults` suite, fake bookmarks and scope access, and a folder
/// tree in the temporary directory with the sample archive's names (`Archiv`, `Archiv/_Neu/Web-Downloads`,
/// `Archiv/_Neu/Scanner`). `remove()` deletes the suite and the folders.
struct TestFolderEnvironment {
  let suiteName = "org.jauer.DocsortTests.\(UUID().uuidString)"
  let defaults: UserDefaults
  let bookmarks = FakeBookmarks()
  let access = RecordingScopeAccess()
  /// The temporary folder holding the archive.
  let root: URL

  init() throws {
    guard let defaults = UserDefaults(suiteName: suiteName) else {
      throw CocoaError(.featureUnsupported)
    }
    self.defaults = defaults
    root = URL.temporaryDirectory.appending(
      path: "DocsortTests-\(UUID().uuidString)", directoryHint: .isDirectory)
    for folder in [webDownloads, scanner] {
      try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    }
  }

  /// `Archiv`, the archive root.
  var archive: URL { root.appending(path: "Archiv", directoryHint: .isDirectory) }
  /// `Archiv/_Neu/Web-Downloads`, an inbox.
  var webDownloads: URL {
    archive.appending(path: "_Neu/Web-Downloads", directoryHint: .isDirectory)
  }
  /// `Archiv/_Neu/Scanner`, an inbox.
  var scanner: URL { archive.appending(path: "_Neu/Scanner", directoryHint: .isDirectory) }

  /// The environment the models under test are built with.
  @MainActor var appEnvironment: AppEnvironment {
    AppEnvironment(
      defaults: defaults,
      folderResolver: FolderResolver(bookmarks: bookmarks, access: access),
      filingHistoryURL: root.appending(path: "FilingHistory.json"))
  }

  /// The folder settings stored in the suite.
  func storedSettings() throws -> FolderSettings? {
    try FolderSettings.preference(in: defaults).load()
  }

  /// The path of `url` as `FolderReference.lastKnownPath` spells it.
  func path(of url: URL) -> String {
    let path = url.standardizedFileURL.path(percentEncoded: false)
    return path.count > 1 && path.hasSuffix("/") ? String(path.dropLast()) : path
  }

  /// Deletes the defaults suite and the temporary folders.
  func remove() {
    defaults.removePersistentDomain(forName: suiteName)
    do {
      try FileManager.default.removeItem(at: root)
    } catch {
      // A leftover folder in the temporary directory does no harm; the next test uses a new one.
      print("Could not remove \(root.path(percentEncoded: false)): \(error)")
    }
  }
}
