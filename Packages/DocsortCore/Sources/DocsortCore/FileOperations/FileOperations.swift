import Foundation

/// Moves files into the archive, creates folders, trashes files, and undoes each of these.
///
/// Guarantees:
/// - Nothing is ever overwritten. Name checks are case- and Unicode-normalisation-insensitive, and the final rename
///   is exclusive in the kernel, so a file that appears after the check still cannot be replaced.
/// - Each operation either completes or leaves the file system as it was; when rolling back fails too, the thrown
///   ``FileOperationError/failed(operation:url:reason:)`` says what is where.
/// - A move to another volume copies first and removes the original only after the copy is complete and only if the
///   original did not change meanwhile; if it did, both are kept
///   (``FileOperationError/originalChangedDuringCopy(original:copy:replaced:)``).
/// - Every record carries the identity (``FileIdentity``) of the item where the operation left it, and undo moves only
///   that item: when another item has taken its place, undo refuses with ``FileOperationError/differentItem(at:)``.
public struct FileOperations: Sendable {
  let trash: any FileTrash
  let renaming: any ExclusiveRenaming
  /// Runs with the original's URL once a cross-volume copy is complete, before the original is checked and removed.
  /// A test seam, so tests can change the original at that moment; it does nothing otherwise.
  let afterCrossVolumeCopy: @Sendable (URL) -> Void

  /// Creates file operations that send items to `trash`.
  public init(trash: any FileTrash = SystemTrash()) {
    self.init(trash: trash, renaming: SystemRenaming())
  }

  init(
    trash: any FileTrash, renaming: any ExclusiveRenaming,
    afterCrossVolumeCopy: @escaping @Sendable (URL) -> Void = { _ in }
  ) {
    self.trash = trash
    self.renaming = renaming
    self.afterCrossVolumeCopy = afterCrossVolumeCopy
  }

  /// The item in `folder` whose name equals `name` ignoring case and Unicode normalisation, as it is named on disk,
  /// or `nil` when there is none or `folder` does not exist.
  public func existingItem(named name: String, in folder: URL) throws(FileOperationError) -> URL? {
    let key = Self.comparisonKey(name)
    guard let match = try itemNames(in: folder).first(where: { Self.comparisonKey($0) == key })
    else {
      return nil
    }
    return folder.appending(path: match)
  }

  /// Moves `source` into `folder` under `name`, creating `folder` and its missing parents first.
  ///
  /// When `name` is taken (see ``existingItem(named:in:)``), `resolution` decides: refuse, keep both under a
  /// numbered name, or send the existing item to the Trash. An item that is `source` itself is not a conflict, so a
  /// file can be renamed in place by changing only the case. On failure nothing is changed: created folders are
  /// removed again and a replaced item is put back. The exception is
  /// ``FileOperationError/originalChangedDuringCopy(original:copy:replaced:)``, which keeps both items and says where.
  public func move(
    _ source: URL, into folder: URL, named name: String, resolution: ConflictResolution
  ) throws(FileOperationError) -> MoveRecord {
    if let problem = FileNaming.validationProblem(for: name) { throw .invalidName(name, problem) }
    guard let sourceItem = try FileSystemItem.item(at: source) else { throw .sourceMissing(source) }

    var targetName = name
    var conflictingItem: URL?
    if let existing = try existingItem(named: name, in: folder),
      try FileSystemItem.item(at: existing) != sourceItem
    {
      switch resolution {
      case .refuse: throw .nameConflict(existing: existing)
      case .keepBoth: targetName = try freeName(for: name, in: folder)
      case .replace: conflictingItem = existing
      }
    }

    let foldersToCreate = try missingFolders(upTo: folder)
    for missingFolder in foldersToCreate {
      let folderName = missingFolder.lastPathComponent
      if let problem = FileNaming.validationProblem(for: folderName) {
        throw .invalidName(folderName, problem)
      }
    }
    let createdFolders = try makeFolders(foldersToCreate)

    var replaced: TrashRecord?
    if let conflictingItem {
      do {
        replaced = try moveToTrash(conflictingItem)
      } catch {
        throw rollBack(after: error, of: source, createdFolders: createdFolders)
      }
    }

    let destination = folder.appending(
      path: targetName, directoryHint: sourceItem.isDirectory ? .isDirectory : .notDirectory)
    do {
      try relocate(source, to: destination)
    } catch .originalChangedDuringCopy(let original, let copy, _) {
      // Both the changed original and the complete copy stay; the copy holds the destination name, so a replaced
      // item cannot go back there and stays in the Trash.
      throw .originalChangedDuringCopy(original: original, copy: copy, replaced: replaced)
    } catch {
      throw rollBack(after: error, of: source, replaced: replaced, createdFolders: createdFolders)
    }
    let movedItem: FileIdentity
    do {
      movedItem = try FileIdentity.ofPlacedItem(at: destination)
    } catch {
      throw rollBack(
        after: error, of: source, movedTo: destination, replaced: replaced,
        createdFolders: createdFolders)
    }
    return MoveRecord(
      originalURL: source, destinationURL: destination, createdFolders: createdFolders,
      replaced: replaced, movedItem: movedItem)
  }

  /// Creates the folders of `relativePath` (components separated by `/`) inside `parent` that do not exist yet and
  /// returns them, outermost first. Existing folders are matched as the volume matches them (on the archive volume:
  /// case-insensitively). Every component is validated before anything is created; on failure, folders created by
  /// this call are removed again.
  @discardableResult
  public func createFolders(_ relativePath: String, in parent: URL) throws(FileOperationError)
    -> [URL]
  {
    let components = relativePath.split(separator: "/", omittingEmptySubsequences: false).map(
      String.init)
    for component in components {
      if let problem = FileNaming.validationProblem(for: component) {
        throw .invalidName(component, problem)
      }
    }
    guard try FileSystemItem.resolvedItem(at: parent)?.isDirectory == true else {
      throw .failed(
        operation: "create folders", url: parent, reason: "the parent folder does not exist")
    }
    let target = components.reduce(parent) { folder, component in
      folder.appending(path: component, directoryHint: .isDirectory)
    }
    return try makeFolders(try missingFolders(upTo: target))
  }

  /// Moves the item at `url` to the Trash. Undo it with ``undo(_:)-(TrashRecord)``.
  public func moveToTrash(_ url: URL) throws(FileOperationError) -> TrashRecord {
    guard try FileSystemItem.item(at: url) != nil else { throw .sourceMissing(url) }
    let trashedURL: URL
    do {
      trashedURL = try trash.moveToTrash(url)
    } catch {
      throw .failed(operation: "move to Trash", url: url, reason: error.localizedDescription)
    }
    let trashedItem: FileIdentity
    do {
      trashedItem = try FileIdentity.ofPlacedItem(at: trashedURL)
    } catch {
      throw rollBack(after: error, of: url, movedTo: trashedURL, createdFolders: [])
    }
    return TrashRecord(originalURL: url, trashedURL: trashedURL, trashedItem: trashedItem)
  }

  /// Why `record` can no longer be undone, or `nil` when ``undo(_:resolution:)`` may proceed. Changes nothing, so the
  /// UI can call it before offering Undo.
  ///
  /// It checks the items the undo would move: ``FileOperationError/sourceMissing(_:)`` when nothing is at the move's
  /// destination, ``FileOperationError/notInTrash(_:)`` when the replaced item left the Trash,
  /// ``FileOperationError/differentItem(at:)`` when another item lies at either place, and
  /// ``FileOperationError/failed(operation:url:reason:)`` when an item cannot be inspected. It does not check the
  /// place the file goes back to; `undo` reports a taken name according to its resolution.
  public func undoBlocker(for record: MoveRecord) -> FileOperationError? {
    do {
      try check(
        record.destinationURL, holds: record.movedItem, missing: FileOperationError.sourceMissing)
      if let replaced = record.replaced {
        try check(
          replaced.trashedURL, holds: replaced.trashedItem, missing: FileOperationError.notInTrash)
      }
      return nil
    } catch {
      return error
    }
  }

  /// Why `record` can no longer be undone, or `nil` when ``undo(_:)-(TrashRecord)`` may proceed. Changes nothing.
  ///
  /// ``FileOperationError/notInTrash(_:)`` when the item left the Trash, ``FileOperationError/differentItem(at:)``
  /// when another item lies at its place there, and ``FileOperationError/failed(operation:url:reason:)`` when it
  /// cannot be inspected. It does not check the place the item goes back to; `undo` reports a taken name.
  public func undoBlocker(for record: TrashRecord) -> FileOperationError? {
    do {
      try check(
        record.trashedURL, holds: record.trashedItem, missing: FileOperationError.notInTrash)
      return nil
    } catch {
      return error
    }
  }

  /// Undoes a move: puts the file back at its original path and name (recreating the original folder if needed),
  /// puts back the item a Replace sent to the Trash, then removes the folders the move created if they are empty
  /// (a folder holding only `.DS_Store` counts as empty). Returns where the file ended up and its identity there.
  ///
  /// Fails, changing nothing, with the error ``undoBlocker(for:)-(MoveRecord)`` reports (notably
  /// ``FileOperationError/differentItem(at:)`` when the item at the destination or in the Trash is not the recorded
  /// one), and with ``FileOperationError/originalLocationTaken(_:)`` when the original name is taken and `resolution`
  /// is ``UndoConflictResolution/refuse``. If only removing an empty folder fails, the file is already back and the
  /// error's reason says so.
  public func undo(
    _ record: MoveRecord, resolution: UndoConflictResolution
  ) throws(FileOperationError) -> RestoredItem {
    if let blocker = undoBlocker(for: record) { throw blocker }
    guard let movedItem = try FileSystemItem.item(at: record.destinationURL) else {
      throw .sourceMissing(record.destinationURL)
    }

    let restoration = try putBack(
      record.destinationURL, item: movedItem, at: record.originalURL, resolution: resolution)

    if let replaced = record.replaced {
      do {
        _ = try undo(replaced)
      } catch {
        throw rollBack(after: error, restoration: restoration, movedBackTo: record.destinationURL)
      }
    }

    do {
      try removeEmptyFolders(record.createdFolders)
    } catch {
      throw .failed(
        operation: "remove folders created by the move", url: restoration.url,
        reason:
          "\(error); the file was already put back at \(restoration.url.path(percentEncoded: false))"
      )
    }
    return restoration.restoredItem
  }

  /// Puts an item from the Trash back where it was, recreating its folder if needed. Returns where it ended up and
  /// its identity there.
  ///
  /// Fails, changing nothing, with the error ``undoBlocker(for:)-(TrashRecord)`` reports (for example
  /// ``FileOperationError/differentItem(at:)`` when another item lies at the recorded place in the Trash), and with
  /// ``FileOperationError/originalLocationTaken(_:)`` when its original name is taken.
  public func undo(_ record: TrashRecord) throws(FileOperationError) -> RestoredItem {
    if let blocker = undoBlocker(for: record) { throw blocker }
    guard let trashedItem = try FileSystemItem.item(at: record.trashedURL) else {
      throw .notInTrash(record.trashedURL)
    }
    return try putBack(
      record.trashedURL, item: trashedItem, at: record.originalURL, resolution: .refuse
    ).restoredItem
  }

  // MARK: - Checking identities

  /// Succeeds when the item at `url` has `identity`. Throws `missing(url)` when nothing is there and
  /// ``FileOperationError/differentItem(at:)`` when another item is.
  private func check(
    _ url: URL, holds identity: FileIdentity, missing: (URL) -> FileOperationError
  ) throws(FileOperationError) {
    guard let found = try FileIdentity.ofItem(at: url) else { throw missing(url) }
    guard found == identity else { throw .differentItem(at: url) }
  }

  // MARK: - Putting items back

  /// Where `putBack` placed an item, the item's identity there, and the folders it had to recreate for that.
  private struct Restoration {
    let url: URL
    let identity: FileIdentity
    let createdFolders: [URL]

    var restoredItem: RestoredItem { RestoredItem(url: url, identity: identity) }
  }

  /// Moves `current` (whose identity is `item`) to `original`, or to a numbered name beside it for
  /// ``UndoConflictResolution/keepBoth``.
  private func putBack(
    _ current: URL, item: FileSystemItem, at original: URL, resolution: UndoConflictResolution
  ) throws(FileOperationError) -> Restoration {
    let folder = original.deletingLastPathComponent()
    let name = original.lastPathComponent
    var targetName = name
    if let existing = try existingItem(named: name, in: folder),
      try FileSystemItem.item(at: existing) != item
    {
      switch resolution {
      case .refuse: throw .originalLocationTaken(original)
      case .keepBoth: targetName = try freeName(for: name, in: folder)
      }
    }

    let createdFolders = try makeFolders(try missingFolders(upTo: folder))
    let target =
      targetName == name
      ? original
      : folder.appending(
        path: targetName, directoryHint: item.isDirectory ? .isDirectory : .notDirectory)
    do {
      try relocate(current, to: target)
    } catch {
      throw rollBack(after: error, of: current, createdFolders: createdFolders)
    }
    do {
      return Restoration(
        url: target, identity: try FileIdentity.ofPlacedItem(at: target),
        createdFolders: createdFolders)
    } catch {
      throw rollBack(after: error, of: current, movedTo: target, createdFolders: createdFolders)
    }
  }

  // MARK: - Rolling back

  /// Undoes the partial work of a failed move and returns the error to throw: `error` itself when the rollback
  /// succeeded, otherwise an error that names both failures. `movedTo` is where the item from `url` already went when
  /// a step after the move itself failed; it is moved back first, and if that fails nothing else is rolled back.
  private func rollBack(
    after error: FileOperationError, of url: URL, movedTo: URL? = nil,
    replaced: TrashRecord? = nil, createdFolders: [URL]
  ) -> FileOperationError {
    var rollbackFailures: [String] = []
    if let movedTo {
      do {
        try relocate(movedTo, to: url)
      } catch {
        rollbackFailures.append(
          "the item stays at \(movedTo.path(percentEncoded: false)) (\(error))")
        return combine(error, about: url, rollbackFailures: rollbackFailures)
      }
    }
    if let replaced {
      do {
        _ = try undo(replaced)
      } catch {
        rollbackFailures.append(
          "the replaced item stays in the Trash at \(replaced.trashedURL.path(percentEncoded: false)) (\(error))"
        )
      }
    }
    do {
      try removeEmptyFolders(createdFolders)
    } catch {
      rollbackFailures.append("created folders could not be removed (\(error))")
    }
    return combine(error, about: url, rollbackFailures: rollbackFailures)
  }

  /// Moves a file that undo already put back to `restoration.url` back to where the move had put it, after a later
  /// step of the undo failed.
  private func rollBack(
    after error: FileOperationError, restoration: Restoration, movedBackTo destination: URL
  ) -> FileOperationError {
    var rollbackFailures: [String] = []
    do {
      try relocate(restoration.url, to: destination)
      try removeEmptyFolders(restoration.createdFolders)
    } catch {
      rollbackFailures.append(
        "the file stays at \(restoration.url.path(percentEncoded: false)) (\(error))")
    }
    return combine(error, about: restoration.url, rollbackFailures: rollbackFailures)
  }

  /// `error` when nothing failed during rollback, otherwise a ``FileOperationError/failed(operation:url:reason:)``
  /// about `url` that names the original failure and every rollback failure.
  private func combine(
    _ error: FileOperationError, about url: URL, rollbackFailures: [String]
  ) -> FileOperationError {
    guard !rollbackFailures.isEmpty else { return error }
    return .failed(
      operation: "roll back", url: url,
      reason: "\(error); rolling back also failed: \(rollbackFailures.joined(separator: "; "))")
  }

  // MARK: - Names

  /// The names of the items in `folder`, or none when `folder` does not exist.
  private func itemNames(in folder: URL) throws(FileOperationError) -> [String] {
    guard try FileSystemItem.resolvedItem(at: folder)?.isDirectory == true else { return [] }
    do {
      return try FileManager.default.contentsOfDirectory(atPath: folder.path(percentEncoded: false))
    } catch {
      throw .failed(operation: "list folder", url: folder, reason: error.localizedDescription)
    }
  }

  /// The first Keep Both name for `name` that no item in `folder` has.
  private func freeName(for name: String, in folder: URL) throws(FileOperationError) -> String {
    let takenKeys = Set(try itemNames(in: folder).map(Self.comparisonKey))
    return FileNaming.keepBothName(for: name) { takenKeys.contains(Self.comparisonKey($0)) }
  }

  /// A key under which names that the archive volume treats as the same compare equal: precomposed and case-folded.
  static func comparisonKey(_ name: String) -> String {
    name.precomposedStringWithCanonicalMapping.folding(options: .caseInsensitive, locale: nil)
  }
}
