import DocsortCore
import Foundation
import Testing

@testable import Docsort

/// Main windows for tests of `MainWindowModel` and the models built on it.
@MainActor
enum TestWindow {
  /// A window model over `environment`: its archive (indexed) and both its inboxes (scanned once), filing with a
  /// history and Trash of the environment, and the undo manager it registers with. Waits until the window can file:
  /// the history is loaded and the picker has the archive's index. Folders the archive needs must exist before.
  static func open(
    on environment: TestFolderEnvironment
  ) async throws -> (model: MainWindowModel, undoManager: UndoManager) {
    let folders = FolderLibrary(environment: environment.appEnvironment)
    folders.setArchiveRoot(to: environment.archive)
    folders.addInbox(folder: environment.webDownloads)
    folders.addInbox(folder: environment.scanner)
    let expectedChanges = ExpectedChanges()
    let inboxes = InboxLibrary(watcher: InboxWatcher(expectedChanges: expectedChanges))
    inboxes.update(inboxes: folders.inboxes)
    await inboxes.waitForScan()
    let historyURL = environment.root.appending(path: "FilingHistory.json")
    let service = FilingService(
      historyURL: historyURL,
      recentsPreference: RecentDestinations.preference(in: environment.defaults),
      fileOperations: FileOperations(
        trash: FixtureTrash(folder: environment.root.appending(path: "Trash"))),
      expectedChanges: expectedChanges)
    let model = MainWindowModel(
      folders: folders, inboxes: inboxes, archive: ArchiveLibrary(folders: folders),
      filing: FilingStatusModel(service: service, historyFileURL: historyURL),
      search: SearchSettings(defaults: environment.defaults))
    let undoManager = UndoManager()
    model.undoManager = undoManager
    try await waitUntil { model.filing.isHistoryWritable && model.picker.index != nil }
    return (model, undoManager)
  }
}
