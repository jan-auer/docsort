import DocsortCore
import Foundation

@testable import Docsort

/// Holds folder listings back until a test lets them finish, to test loading states and stale results.
actor FolderListingGate {
  private var openFolders: Set<String> = []
  private var waiting: [String: [CheckedContinuation<Void, Never>]] = [:]

  /// Returns once ``open(_:)`` was called for `folder`.
  func waitUntilOpen(_ folder: String) async {
    guard !openFolders.contains(folder) else { return }
    await withCheckedContinuation { continuation in
      waiting[folder, default: []].append(continuation)
    }
  }

  /// Lets every listing of `folder`, waiting or later, finish.
  func open(_ folder: String) {
    openFolders.insert(folder)
    for continuation in waiting.removeValue(forKey: folder) ?? [] {
      continuation.resume()
    }
  }
}

/// A folder listing for tests: lists the fixture archive through the index, optionally held back by a gate, and
/// fails for the folders it is told to.
nonisolated struct FakeFolderFileListing: FolderFileListing {
  /// The reason given for folders in ``unreadableFolders``.
  static let unreadableReason = "Permission denied"

  /// Holds listings back until the test opens their folder; `nil` lists at once.
  var gate: FolderListingGate?
  /// Folders whose listing fails with ``FolderAccessError/unreadable(_:reason:)``.
  var unreadableFolders: Set<String> = []

  func files(in folder: String, of index: DestinationIndex) async throws(FolderAccessError)
    -> [FolderFile]
  {
    await gate?.waitUntilOpen(folder)
    if unreadableFolders.contains(folder) {
      throw .unreadable(index.url(for: folder), reason: Self.unreadableReason)
    }
    return try index.files(in: folder)
  }
}
