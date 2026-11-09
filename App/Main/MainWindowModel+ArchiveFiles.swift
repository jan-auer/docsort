import DocsortCore
import Foundation
import OSLog

/// Rename… and Move to Trash in the menu of a file in Folder contents: archive files, renamed and trashed through the
/// `FilingService` like inbox files, so the filing history records them, ⌘Z undoes them, and an inbox row that filed
/// the file follows it (its new name, or trashed with Put Back).
extension MainWindowModel {
  /// Whether archive files can be renamed and trashed: the history is writable and nothing is being filed.
  var canChangeArchiveFiles: Bool {
    filing.isHistoryWritable && !isFilingInProgress
  }

  /// Renames the archive file `file` in its folder to `enteredName`, entered without the extension, which the file
  /// keeps (as in the name field). A name macOS forbids, or one taken in the folder, is refused with an alert.
  func renameArchiveFile(_ file: FolderFile, to enteredName: String) {
    guard canChangeArchiveFiles else { return }
    let name = FileNaming.finalName(entered: enteredName, originalName: file.name)
    guard name != file.name else { return }
    if let problem = FileNaming.validationProblem(for: name) {
      alert = FilingAlert(
        title: "“\(file.name)” can’t be renamed", message: FilingMessages.text(for: problem))
      return
    }
    let request = ArchiveRenameRequest(source: file.url, name: name, originalName: file.name)
    startFilingOperation { await self.perform(request) }
  }

  /// Moves the archive file `file` to the Trash, without confirmation (it can be undone).
  func trashArchiveFile(_ file: FolderFile) {
    guard canChangeArchiveFiles else { return }
    let request = ArchiveTrashRequest(
      url: file.url, originalName: file.name,
      selectionAfter: picker.contentsFile(replacing: file)?.url)
    startFilingOperation { await self.perform(request) }
  }

  private func perform(_ request: ArchiveRenameRequest) async {
    do {
      let outcome = try await filing.rename(request.source, to: request.name)
      let filedRows = applyRename(outcome)
      registerUndo(
        of: .archiveRename(request, filedRows: filedRows),
        ticket: FilingEventTicket(eventID: outcome.event.id))
      statusMessage = WindowStatusMessage(
        text: "Renamed “\(request.originalName)” to \(request.name) · Undo ⌘Z")
    } catch {
      Logger.filing.error(
        "Renaming \(request.originalName, privacy: .private) failed: \(String(describing: error), privacy: .private)"
      )
      alert = FilingAlert(
        title: "“\(request.originalName)” can’t be renamed",
        message: FilingMessages.text(for: error))
    }
  }

  private func perform(_ request: ArchiveTrashRequest) async {
    do {
      let outcome = try await filing.trash(request.url)
      let filedRows = applyTrash(outcome, selectingAfterwards: request.selectionAfter)
      registerUndo(
        of: .archiveTrash(request, filedRows: filedRows),
        ticket: FilingEventTicket(eventID: outcome.event.id))
      statusMessage = WindowStatusMessage(
        text: "Moved “\(request.originalName)” to the Trash · Undo ⌘Z")
    } catch {
      Logger.filing.error(
        "Trashing \(request.originalName, privacy: .private) failed: \(String(describing: error), privacy: .private)"
      )
      alert = FilingAlert(
        title: "“\(request.originalName)” could not be moved to the Trash",
        message: FilingMessages.text(for: error))
    }
  }

  /// After a rename: the rows that filed the file show its new name, and Folder contents lists it, selected. Returns
  /// those rows with their earlier marks, for undo.
  @discardableResult
  func applyRename(_ outcome: MoveOutcome) -> [MarkedRow] {
    let filedRows = remark(filedAs: outcome.event.documentID) { mark in
      guard case .filed(_, let destinationPath, _, let documentID) = mark else { return mark }
      return .filed(
        newURL: outcome.movedURL, destinationPath: destinationPath, date: outcome.event.date,
        documentID: documentID)
    }
    picker.reloadContents(selecting: outcome.movedURL)
    return filedRows
  }

  /// After a move to the Trash: the rows that filed the file show it trashed (with Put Back), and Folder contents
  /// lists the folder again with `selection` selected. Returns those rows with their earlier marks, for undo.
  @discardableResult
  func applyTrash(_ outcome: TrashOutcome, selectingAfterwards selection: URL?) -> [MarkedRow] {
    let filedRows = remark(filedAs: outcome.event.documentID) { _ in
      .trashed(trashedURL: outcome.record.trashedURL, date: outcome.event.date)
    }
    picker.reloadContents(selecting: selection)
    return filedRows
  }

  /// Puts back the marks `rows` had before an archive file's rename or move to the Trash.
  func restoreMarks(of rows: [MarkedRow]) {
    for row in rows {
      inboxes.setMark(row.id, row.markBefore)
    }
    nameFieldFollowsSelectedFile(amongRows: rows)
  }

  /// When the selected file is one of `rows`, puts its current name into the name field, so the panel sees no rename
  /// the user did not ask for (⌘Return would otherwise rename it back).
  private func nameFieldFollowsSelectedFile(amongRows rows: [MarkedRow]) {
    guard let selectedFile, rows.contains(where: { $0.id == selectedFile.id }) else { return }
    panel.reset(currentName: selectedFile.name)
  }

  /// Gives every row that filed the history's document `documentID` the mark `newMark` makes of its current one, and
  /// returns those rows with their earlier marks.
  private func remark(
    filedAs documentID: UUID, _ newMark: (InboxItemMark) -> InboxItemMark
  ) -> [MarkedRow] {
    var rows: [MarkedRow] = []
    for id in inboxes.rowIDs(filedAs: documentID) {
      guard let markBefore = inboxes.row(for: id)?.mark else { continue }
      inboxes.setMark(id, newMark(markBefore))
      rows.append(MarkedRow(id: id, markBefore: markBefore))
    }
    nameFieldFollowsSelectedFile(amongRows: rows)
    return rows
  }
}
