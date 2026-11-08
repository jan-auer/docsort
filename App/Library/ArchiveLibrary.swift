import DocsortCore
import Foundation
import OSLog
import Observation

/// What the archive index is built from: the usable archive root and the inbox folders it leaves out.
nonisolated struct ArchiveIndexRequest: Equatable, Sendable {
  /// The archive root, with its security scope active.
  let root: URL
  /// The usable inbox folders; those inside the archive are left out of the index.
  let excludedFolders: Set<URL>

  /// A request for `root`, leaving out `excludedFolders`.
  init(root: URL, excludedFolders: Set<URL>) {
    self.root = root
    self.excludedFolders = excludedFolders
  }

  /// The request for `folders`' current folders, or `nil` while it has no usable archive root.
  @MainActor init?(folders: FolderLibrary) {
    guard let root = folders.archiveRoot?.url else { return nil }
    self.init(root: root, excludedFolders: Set(folders.inboxes.compactMap(\.url)))
  }
}

/// A folder below the archive root that the index could not include.
nonisolated struct ArchiveIndexProblem: Hashable, Sendable {
  /// Why the folder is not in the index.
  enum Kind: Hashable, Sendable {
    /// A symbolic link, which the index never follows.
    case symbolicLink
    /// A folder or entry that could not be read.
    case unreadable
  }

  /// The item that was left out.
  let url: URL
  /// Why it was left out, in the file system's words.
  let reason: String
  /// What kind of problem it is.
  let kind: Kind
}

/// How far the archive index is, as Settings and the destination picker show it.
nonisolated enum ArchiveIndexStatus: Hashable, Sendable {
  /// There is no usable archive root to index.
  case unavailable
  /// The index is being built.
  case indexing
  /// The index is ready with `folderCount` folders; `problems` lists what it left out.
  case ready(folderCount: Int, problems: [ArchiveIndexProblem])
  /// The archive root could not be walked at all; `reason` is a sentence for the user.
  case failed(reason: String)
}

/// The index of archive folders that destinations are searched in, rebuilt whenever the archive root or the inbox
/// folders change.
///
/// One per app. It watches a `FolderLibrary` and builds `DestinationIndex` in a `@concurrent` function, off the
/// main actor, leaving out the inbox folders. A build whose request has been superseded is cancelled and its result
/// ignored. Like `FolderLibrary`, it uses only Foundation, Observation and DocsortCore.
@Observable
final class ArchiveLibrary {
  /// How far the index is.
  private(set) var status: ArchiveIndexStatus = .unavailable
  /// The index, once built; `nil` while there is none or it is being rebuilt.
  private(set) var index: DestinationIndex?

  /// The request the current status and index belong to.
  @ObservationIgnored private var request: ArchiveIndexRequest?
  @ObservationIgnored private var buildTask: Task<Void, Never>?
  @ObservationIgnored private var observationTask: Task<Void, Never>?

  /// An archive library that is told what to index through `update(to:)`.
  init() {}

  /// An archive library that indexes `folders`' archive root, and rebuilds whenever its folders change.
  convenience init(folders: FolderLibrary) {
    self.init()
    observationTask = Task { [weak self] in
      for await request in Observations({ ArchiveIndexRequest(folders: folders) }) {
        guard let self else { return }
        update(to: request)
      }
    }
  }

  isolated deinit {
    observationTask?.cancel()
    buildTask?.cancel()
  }

  /// Builds the index for `request`, unless it is the request already built or being built; `nil` clears it.
  func update(to request: ArchiveIndexRequest?) {
    guard request != self.request else { return }
    self.request = request
    buildTask?.cancel()
    index = nil
    guard let request else {
      buildTask = nil
      status = .unavailable
      return
    }
    status = .indexing
    startBuild(for: request)
  }

  /// Builds the index again for the same folders, for example after a move created folders in the archive or its
  /// undo removed them. The current index stays in use (and the status unchanged) until the new one is ready, so the
  /// picker keeps working meanwhile.
  func rebuild() {
    guard let request else { return }
    buildTask?.cancel()
    startBuild(for: request)
  }

  /// Builds the index for `request` off the main actor and applies it when done.
  private func startBuild(for request: ArchiveIndexRequest) {
    buildTask = Task { [weak self] in
      let outcome = await Self.build(request)
      self?.apply(outcome, for: request)
    }
  }

  /// Waits until the build in progress, if any, has finished and been applied.
  func waitForIndexing() async {
    await buildTask?.value
  }

  /// Applies a finished build, unless its request has been superseded meanwhile.
  private func apply(_ outcome: ArchiveIndexBuild, for request: ArchiveIndexRequest) {
    guard request == self.request, !Task.isCancelled else {
      Logger.archiveIndex.debug("Ignoring an archive index built for superseded folders")
      return
    }
    switch outcome {
    case .built(let builtIndex, let problems):
      index = builtIndex
      status = .ready(folderCount: builtIndex.folders.count, problems: problems)
      let linkCount = problems.count { $0.kind == .symbolicLink }
      Logger.archiveIndex.notice(
        "Indexed \(builtIndex.folders.count, privacy: .public) archive folders; \(problems.count, privacy: .public) left out, \(linkCount, privacy: .public) of them symbolic links"
      )
    case .failed(let error):
      status = .failed(reason: Self.reason(for: error))
      Logger.archiveIndex.error(
        "Could not index the archive: \(String(describing: error), privacy: .private)")
    }
  }

  /// The outcome of one index build.
  private enum ArchiveIndexBuild: Sendable {
    case built(DestinationIndex, problems: [ArchiveIndexProblem])
    case failed(FolderAccessError)
  }

  /// Walks the archive for `request` and classifies what the walk left out.
  @concurrent private static func build(_ request: ArchiveIndexRequest) async -> ArchiveIndexBuild {
    let builtIndex: DestinationIndex
    do {
      builtIndex = try DestinationIndex.build(
        root: request.root, excluding: Array(request.excludedFolders))
    } catch {
      return .failed(error)
    }
    let problems = builtIndex.problems.map { problem in
      ArchiveIndexProblem(url: problem.url, reason: problem.reason, kind: kind(of: problem))
    }
    return .built(builtIndex, problems: problems)
  }

  /// Whether `problem` is a symbolic link, found by looking at the item itself (one stat, off the main actor).
  nonisolated private static func kind(of problem: ScanProblem) -> ArchiveIndexProblem.Kind {
    do {
      let values = try problem.url.resourceValues(forKeys: [.isSymbolicLinkKey])
      return values.isSymbolicLink == true ? .symbolicLink : .unreadable
    } catch {
      // An item that cannot even be looked at is unreadable, which is what the walk reported for it anyway.
      return .unreadable
    }
  }

  /// A sentence for the user saying why the archive could not be indexed.
  private static func reason(for error: FolderAccessError) -> String {
    switch error {
    case .notFound:
      "The archive folder was not found."
    case .notAFolder:
      "The archive folder is not a folder."
    case .unreadable(_, let reason):
      reason
    }
  }
}
