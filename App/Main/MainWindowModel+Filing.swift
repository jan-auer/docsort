import DocsortCore
import Foundation
import OSLog

/// What a move does to the file.
nonisolated enum MoveKind: Hashable, Sendable {
  /// Files an inbox file into the archive.
  case filing
  /// Renames the filed file, the filing history's document `documentID`, in its folder.
  case renaming(documentID: UUID)
  /// Moves the filed file, the filing history's document `documentID`, on to another folder (and possibly renames
  /// it).
  case refiling(documentID: UUID)

  /// The filing history's document of the filed file that is renamed or moved on; `nil` when filing an inbox file.
  var filedDocumentID: UUID? {
    switch self {
    case .filing: nil
    case .renaming(let documentID), .refiling(let documentID): documentID
    }
  }

  /// Whether the move renames a filed file in its folder.
  var isRenaming: Bool {
    if case .renaming = self { true } else { false }
  }
}

/// A move the user asked for, with everything needed to retry or redo it.
nonisolated struct MoveRequest: Hashable, Sendable {
  /// The file's identity.
  let itemID: InboxItemID
  /// Where the file is now.
  let source: URL
  /// The destination folder.
  let folderURL: URL
  /// The destination's archive-relative path.
  let archivePath: String
  /// The name to file under, with its extension.
  let name: String
  /// The file's inbox name, for the Undo menu item.
  let originalName: String
  /// What the move does to the file.
  let kind: MoveKind
}

/// A Move Back of a filed file to its inbox the user asked for.
nonisolated struct MoveBackRequest: Hashable, Sendable {
  /// The file's identity.
  let itemID: InboxItemID
  /// The filing history's document the row filed; the Move Back refuses unless it is still the file at `url`.
  let documentID: UUID
  /// Where the file is now, in the archive.
  let url: URL
  /// The file's inbox name, for the Undo menu item.
  let originalName: String
  /// The display name of the file's inbox.
  let inboxName: String
}

/// A move to the Trash the user asked for.
nonisolated struct TrashRequest: Hashable, Sendable {
  /// The file's identity.
  let itemID: InboxItemID
  /// Where the file is now.
  let url: URL
  /// The file's inbox name, for the Undo menu item.
  let originalName: String
}

/// A Put Back of a trashed file the user asked for.
nonisolated struct PutBackRequest: Hashable, Sendable {
  /// The file's identity.
  let itemID: InboxItemID
  /// Where the file lies in the Trash.
  let trashedURL: URL
  /// The file's inbox name, for the Undo menu item.
  let originalName: String
}

/// A name conflict waiting for the user's choice between Keep Both, Replace and Cancel.
nonisolated struct FilingConflict: Identifiable, Sendable {
  /// Distinguishes this conflict from the previous one.
  let id = UUID()
  /// The name of the item already in the destination.
  let existingName: String
  /// The move that ran into it.
  let request: MoveRequest
}

/// A Move Back whose inbox name is taken, waiting for the user's choice between Keep Both and Cancel.
nonisolated struct MoveBackConflict: Identifiable, Sendable {
  /// Distinguishes this conflict from the previous one.
  let id = UUID()
  /// The item in the way, at the file's original inbox path.
  let blockingURL: URL
  /// The Move Back that ran into it.
  let request: MoveBackRequest
}

/// What ⌘Return does to the selected filed file, which the bottom button names.
nonisolated enum FiledFileChange: Hashable, Sendable {
  /// Only the name differs: rename it in its folder.
  case rename
  /// The folder differs (or none is chosen): move it on.
  case move
}

/// What returns a handled file to its inbox (File › Move Back to Inbox, ⌥⌘Z, the status strip, the row's menu).
nonisolated enum ReturnToInboxAction: Hashable, Sendable {
  /// A filed file: Move Back.
  case moveBack
  /// A trashed file: Put Back.
  case putBack
}

extension SelectedFile {
  /// What returns the file to its inbox; `nil` while it is unhandled.
  var returnToInboxAction: ReturnToInboxAction? {
    switch mark {
    case .filed: .moveBack
    case .trashed: .putBack
    case nil: nil
    }
  }
}

/// A row with the mark it had before an action that changed it (a Replace sent its filed file to the Trash, or its
/// filed file was renamed or trashed in Folder contents), which undoing the action restores.
nonisolated struct MarkedRow: Sendable {
  /// The row's identity.
  let id: InboxItemID
  /// The row's mark before the Replace.
  let markBefore: InboxItemMark
}

/// An action on the window's undo stack.
///
/// Undo puts the row back to the mark it had before the action and redo performs the action again. Where the action
/// is exactly reversible (moves and Move Back put the file back under the refused-on-conflict rule, so at its old
/// place) the earlier mark is stored; marks naming a new place in the Trash or a new date come from the outcome.
nonisolated enum UndoableFiling: Sendable {
  /// A move, redone with `resolution` (Replace again, or refuse a conflict); undo restores `markBefore` (none for a
  /// filing, the earlier filed mark for a rename or move of a filed file), and the marks of `replacedRows`, the rows
  /// whose files a Replace sent to the Trash.
  case move(
    MoveRequest, resolution: ConflictResolution, markBefore: InboxItemMark?,
    replacedRows: [MarkedRow])
  /// A Move Back, redone with `resolution`; undo returns the file to the archive and restores `markBefore`.
  case moveBack(MoveBackRequest, resolution: ConflictResolution, markBefore: InboxItemMark?)
  /// A move to the Trash.
  case trash(TrashRequest)
  /// A Put Back, which returned the file to `returnedTo` (its inbox, or the archive folder it was trashed from) and
  /// gave the row `markAfter`; undo moves the file to the Trash again.
  case putBack(PutBackRequest, returnedTo: URL, markAfter: InboxItemMark?)
  /// A rename of an archive file from Folder contents; undo restores the marks of `filedRows`, the rows that filed it.
  case archiveRename(ArchiveRenameRequest, filedRows: [MarkedRow])
  /// A move to the Trash of an archive file from Folder contents; undo restores the marks of `filedRows`.
  case archiveTrash(ArchiveTrashRequest, filedRows: [MarkedRow])

  /// The inbox row the action is about, which undo and redo select; `nil` for an archive file.
  var itemID: InboxItemID? {
    switch self {
    case .move(let request, _, _, _): request.itemID
    case .moveBack(let request, _, _): request.itemID
    case .trash(let request): request.itemID
    case .putBack(let request, _, _): request.itemID
    case .archiveRename, .archiveTrash: nil
    }
  }

  /// The Edit menu's name for the action.
  var actionName: String {
    switch self {
    case .move(let request, _, _, _):
      request.kind.isRenaming
        ? "Rename of “\(request.originalName)”" : "Move of “\(request.originalName)”"
    case .moveBack(let request, _, _): "Move Back of “\(request.originalName)”"
    case .trash(let request): "Move to Trash of “\(request.originalName)”"
    case .putBack(let request, _, _): "Put Back of “\(request.originalName)”"
    case .archiveRename(let request, _): "Rename of “\(request.originalName)”"
    case .archiveTrash(let request, _): "Move to Trash of “\(request.originalName)”"
    }
  }
}

/// The history event the next undo or redo step acts on; filled in by the step before it once it completes, after
/// the next step was registered.
final class FilingEventTicket {
  var eventID: FilingEvent.ID?

  init(eventID: FilingEvent.ID? = nil) {
    self.eventID = eventID
  }
}

extension MainWindowModel {
  // MARK: Destinations

  /// Starts the destination filter with `text` typed in the sidebar and moves focus there.
  ///
  /// A new search starts at the archive root; keys typed before the filter has taken focus are appended.
  func startDestinationFilter(with text: String) {
    if !panel.isFilterFocusPending { picker.reset() }
    picker.enter(typing: text)
    panel.notice = nil
    requestFocus(.destinationFilter)
  }

  /// Acts on what the destination picker reports (see `PickerContract`).
  func handlePickerEvent(_ event: PickerEvent) {
    switch event {
    case .chose:
      panel.notice = nil
      requestFocus(.nameField)
    case .moveRequested(let destination):
      move(to: destination)
    case .steppedBack:
      requestFocus(.sidebar)
    case .tookFileName(let fileName):
      panel.nameText = FileNameParts(fileName).stem
      requestFocus(.nameField)
    case .renameFileRequested(let file, let name):
      renameArchiveFile(file, to: name)
    case .trashFileRequested(let file):
      trashArchiveFile(file)
    case .refreshRequested:
      refresh()
    }
  }

  // MARK: Moving

  /// Whether the filing panel's picker and name field take input for the selected file: a complete file that is
  /// unhandled or filed (not trashed), with the archive available and the history writable.
  var canChooseDestination: Bool {
    guard let file = selectedFile, file.completeness == .complete, !file.isTrashed else {
      return false
    }
    return archiveAvailability == .available && filing.isHistoryWritable && !isFilingInProgress
  }

  /// For a selected filed file, what ⌘Return would change: `.rename` when only the name differs, `.move` when the
  /// chosen folder differs or no folder is chosen, `nil` when nothing changed or the file is not filed.
  var filedFileChange: FiledFileChange? {
    guard let file = selectedFile, case .filed(_, let destinationPath, _, _) = file.mark else {
      return nil
    }
    guard let destination = picker.destination, destination.path == destinationPath else {
      return .move
    }
    return finalName == file.name ? nil : .rename
  }

  /// Whether the selected file can be moved: an unhandled file, or a filed one whose folder or name was changed, as
  /// `canChooseDestination` allows.
  var canMoveSelectedFile: Bool {
    guard canChooseDestination, let file = selectedFile else { return false }
    return file.mark == nil || filedFileChange != nil
  }

  /// The name the selected file would be filed under, from the name field (empty keeps its current name).
  var finalName: String? {
    guard let file = selectedFile else { return nil }
    return FileNaming.finalName(entered: panel.nameText, originalName: file.name)
  }

  /// The name Folder contents flags as taken: the final name, except a filed file's own name (in any case) while
  /// its own folder is chosen, which a rename in place may keep or change the case of.
  var nameToCheckForConflicts: String? {
    guard let file = selectedFile, let name = finalName else { return nil }
    if case .filed(_, let destinationPath, _, _) = file.mark,
      picker.destination?.path == destinationPath,
      name.caseInsensitiveCompare(file.name) == .orderedSame
    {
      return nil
    }
    return name
  }

  /// File › Move (⌘Return) and the Move (or Rename) button: moves the selected file to the chosen destination under
  /// the entered name.
  ///
  /// With no destination chosen: while focus is in the picker (a click on Move), the picker's highlighted folder is
  /// chosen and the file moves, as ⌘Return in the picker does (the picker handles that key itself). Anywhere else
  /// nothing moves: focus goes to the filter and the hint says "Choose a destination first". With the filing panel
  /// hidden, it shows the panel and moves nothing.
  func moveSelectedFile() {
    guard canMoveSelectedFile else { return }
    guard isFilingPanelShown else {
      // The destination and name are not visible: show them instead of moving to something the user can't see.
      requestFocus(.destinationFilter)
      return
    }
    if let destination = picker.destination {
      move(to: destination)
    } else if focus == .destinationFilter, picker.highlightedDestination != nil {
      picker.requestMove()
    } else {
      panel.hint = .chooseDestinationFirst
      requestFocus(.destinationFilter)
    }
  }

  /// Moves the selected file into `destination` under the entered name: files an unhandled file, renames or moves on
  /// a filed one.
  private func move(to destination: PickerDestination) {
    guard canMoveSelectedFile, let file = selectedFile, let index = archive.index else { return }
    let name = FileNaming.finalName(entered: panel.nameText, originalName: file.name)
    guard FileNaming.validationProblem(for: name) == nil else {
      requestFocus(.nameField)
      return
    }
    let kind: MoveKind =
      if case .filed(_, let destinationPath, _, let documentID) = file.mark {
        destination.path == destinationPath
          ? .renaming(documentID: documentID) : .refiling(documentID: documentID)
      } else {
        .filing
      }
    let request = MoveRequest(
      itemID: file.id, source: file.url, folderURL: index.url(for: destination.path),
      archivePath: destination.path, name: name, originalName: file.originalName, kind: kind)
    Task { await perform(request, resolution: .refuse) }
  }

  /// Retries the move of `conflict` with `resolution` (Keep Both or Replace).
  func resolve(_ conflict: FilingConflict, with resolution: ConflictResolution) {
    Task { await perform(conflict.request, resolution: resolution) }
  }

  /// Cancels the move of a conflict and returns to the name field.
  func cancelConflict() {
    requestFocus(.nameField)
  }

  private func perform(_ request: MoveRequest, resolution: ConflictResolution) async {
    guard !isFilingInProgress else { return }
    isFilingInProgress = true
    defer { isFilingInProgress = false }
    let markBefore = inboxes.row(for: request.itemID)?.mark
    do {
      let outcome = try await moveFile(of: request, resolution: resolution)
      let replacedRows = applyMarks(of: outcome, for: request)
      if !outcome.record.createdFolders.isEmpty { archive.rebuild() }
      let filedName = outcome.movedURL.lastPathComponent
      let redoRequest = MoveRequest(
        itemID: request.itemID, source: request.source, folderURL: request.folderURL,
        archivePath: request.archivePath, name: filedName, originalName: request.originalName,
        kind: request.kind)
      registerUndo(
        of: .move(
          redoRequest, resolution: resolution == .replace ? .replace : .refuse,
          markBefore: markBefore, replacedRows: replacedRows),
        ticket: FilingEventTicket(eventID: outcome.event.id))
      statusMessage = WindowStatusMessage(
        text: request.kind.isRenaming
          ? "Renamed to \(filedName) · Undo ⌘Z"
          : "Moved to \(request.archivePath) as \(filedName) · Undo ⌘Z")
      finishMove(of: request)
    } catch .fileOperation(.nameConflict(let existing)) {
      conflict = FilingConflict(existingName: existing.lastPathComponent, request: request)
    } catch .fileChangedSinceFiling(let url) {
      Logger.filing.error(
        "Refused to move \(url.lastPathComponent, privacy: .private): another file is there since it was filed"
      )
      alert = FilingAlert(
        title: request.kind.isRenaming
          ? "“\(request.originalName)” can’t be renamed"
          : "“\(request.originalName)” can’t be moved",
        message: FilingMessages.text(for: .fileChangedSinceFiling(url)))
    } catch {
      Logger.filing.error(
        "Moving \(request.originalName, privacy: .private) failed: \(String(describing: error), privacy: .private)"
      )
      panel.notice = FilingMessages.text(for: error)
    }
  }

  /// Files the inbox file of `request`, or renames or moves on its filed file, refusing when that file is no longer
  /// the document the row filed.
  private func moveFile(
    of request: MoveRequest, resolution: ConflictResolution
  ) async throws(FilingError) -> MoveOutcome {
    if let documentID = request.kind.filedDocumentID {
      try await filing.refile(
        document: documentID, at: request.source, into: request.folderURL,
        archivePath: request.archivePath, named: request.name, resolution: resolution)
    } else {
      // The caller marks the row with the outcome; until then the row stays, whatever the watcher delivers.
      try await inboxes.keepingRow(request.itemID) { () async throws(FilingError) in
        try await filing.file(
          request.source, into: request.folderURL, archivePath: request.archivePath,
          named: request.name, resolution: resolution)
      }
    }
  }

  /// After a move: marks the moved row as filed, and the rows whose filed files a Replace sent to the Trash as
  /// trashed, so their status strips say so (and Put Back gets the history's refusal instead of acting on the file
  /// that took their place). Returns those rows with their earlier marks, for undo.
  private func applyMarks(of outcome: MoveOutcome, for request: MoveRequest) -> [MarkedRow] {
    var replacedRows: [MarkedRow] = []
    if let replacedEvent = outcome.replacedEvent, case .trashed(let record) = replacedEvent.action {
      for id in inboxes.rowIDs(filedAs: replacedEvent.documentID) {
        guard let markBefore = inboxes.row(for: id)?.mark else { continue }
        inboxes.setMark(id, .trashed(trashedURL: record.trashedURL, date: replacedEvent.date))
        replacedRows.append(MarkedRow(id: id, markBefore: markBefore))
      }
    }
    inboxes.setMark(
      request.itemID,
      .filed(
        newURL: outcome.movedURL, destinationPath: request.archivePath, date: outcome.event.date,
        documentID: outcome.event.documentID))
    return replacedRows
  }

  /// After a move: filing an inbox file advances to the next unhandled file; renaming or moving on a filed file stays
  /// on its row.
  private func finishMove(of request: MoveRequest) {
    switch request.kind {
    case .filing: finishHandling(request.itemID)
    case .renaming, .refiling: showReturned(request.itemID)
    }
  }

  // MARK: Reverting the name

  /// Whether the name field differs from the name the selected file had in its inbox, so Revert (↺, ⇧⌘R) applies.
  var canRevertName: Bool {
    guard let file = selectedFile, file.completeness == .complete, !file.isTrashed else {
      return false
    }
    return finalName != file.originalName
  }

  /// The ↺ button and File › Revert Name (⇧⌘R): puts the name the file had in its inbox back into the name field,
  /// selected. It renames nothing on disk; ⌘Return does.
  func revertName() {
    guard canRevertName, let file = selectedFile else { return }
    panel.nameText = FileNameParts(file.originalName).stem
    requestFocus(.nameField)
  }

  // MARK: Trashing

  /// Whether the selected file can be moved to the Trash; see `canTrash(_:)`.
  var canTrashSelectedFile: Bool {
    guard let file = selectedFile else { return false }
    return canTrash(file)
  }

  /// Whether `file` can be moved to the Trash: an unhandled file, with the history writable.
  func canTrash(_ file: SelectedFile) -> Bool {
    file.mark == nil && filing.isHistoryWritable && !isFilingInProgress
  }

  /// File › Move to Trash (⌘⌫): moves the selected file to the Trash, without confirmation (it can be undone).
  func trashSelectedFile() {
    guard let file = selectedFile else { return }
    trash(file)
  }

  /// Moves `file` to the Trash, without confirmation (it can be undone).
  func trash(_ file: SelectedFile) {
    guard canTrash(file) else { return }
    let request = TrashRequest(itemID: file.id, url: file.url, originalName: file.originalName)
    Task { await perform(request) }
  }

  private func perform(_ request: TrashRequest) async {
    guard !isFilingInProgress else { return }
    isFilingInProgress = true
    defer { isFilingInProgress = false }
    do {
      let outcome = try await trashKeepingRow(request.itemID, url: request.url)
      inboxes.setMark(
        request.itemID,
        .trashed(trashedURL: outcome.record.trashedURL, date: outcome.event.date))
      registerUndo(of: .trash(request), ticket: FilingEventTicket(eventID: outcome.event.id))
      statusMessage = WindowStatusMessage(
        text: "Moved “\(request.originalName)” to the Trash · Undo ⌘Z")
      finishHandling(request.itemID)
    } catch {
      Logger.filing.error(
        "Trashing \(request.originalName, privacy: .private) failed: \(String(describing: error), privacy: .private)"
      )
      alert = FilingAlert(
        title: "“\(request.originalName)” could not be moved to the Trash",
        message: FilingMessages.text(for: error))
    }
  }

  /// Moves the file of row `id` at `url` to the Trash, keeping the row until the caller marks it with the outcome.
  private func trashKeepingRow(_ id: InboxItemID, url: URL) async throws(FilingError)
    -> TrashOutcome
  {
    try await inboxes.keepingRow(id) { () async throws(FilingError) in
      try await filing.trash(url)
    }
  }

  /// After a file was handled: selects the next unhandled file, resets the panel and returns focus to the sidebar.
  private func finishHandling(_ id: InboxItemID) {
    if let next = inboxes.nextUnhandledRow(after: id) {
      select(next.id)
    }
    resetPanel()
    requestFocus(.sidebar)
  }

  /// After a file changed in place (renamed, moved back, put back, or an undo): selects it, resets the panel for it
  /// and returns focus to the sidebar.
  private func showReturned(_ id: InboxItemID) {
    select(id)
    resetPanel()
    requestFocus(.sidebar)
  }

  // MARK: Move Back and Put Back

  /// What ⌥⌘Z does for the selected file: Move Back for a filed file, Put Back for a trashed one, `nil` otherwise.
  var selectedReturnToInboxAction: ReturnToInboxAction? {
    selectedFile?.returnToInboxAction
  }

  /// Whether the selected file can be returned to its inbox; see `canReturnToInbox(_:)`.
  var canReturnSelectedFileToInbox: Bool {
    guard let file = selectedFile else { return false }
    return canReturnToInbox(file)
  }

  /// Whether `file` can be returned to its inbox: it was filed or trashed, and the history is writable.
  func canReturnToInbox(_ file: SelectedFile) -> Bool {
    file.returnToInboxAction != nil && filing.isHistoryWritable && !isFilingInProgress
  }

  /// File › Move Back to Inbox / Put Back (⌥⌘Z) and the status strip's button, for the selected file.
  func returnSelectedFileToInbox() {
    guard let file = selectedFile else { return }
    returnToInbox(file)
  }

  /// Returns `file` to its inbox: moves a filed file back under its inbox name, puts a trashed file back.
  func returnToInbox(_ file: SelectedFile) {
    guard canReturnToInbox(file) else { return }
    switch file.mark {
    case .filed(_, _, _, let documentID):
      let request = MoveBackRequest(
        itemID: file.id, documentID: documentID, url: file.url, originalName: file.originalName,
        inboxName: file.inboxName)
      Task { await perform(request, resolution: .refuse) }
    case .trashed(let trashedURL, _):
      let request = PutBackRequest(
        itemID: file.id, trashedURL: trashedURL, originalName: file.originalName)
      Task { await perform(request) }
    case nil:
      return
    }
  }

  /// The mark a row gets once Put Back returned its file, the history's document `documentID`, to `url`: none in an
  /// inbox; filed in the archive folder it was trashed from (from Folder contents), so it can be moved back from there.
  func mark(afterPutBackTo url: URL, documentID: UUID) -> InboxItemMark? {
    guard inboxLabel(ofFolderHolding: url) == nil, let root = folders.archiveRoot?.url,
      let destinationPath = DestinationIndex.archiveRelativePath(
        of: url.deletingLastPathComponent(), under: root)
    else { return nil }
    return .filed(
      newURL: url, destinationPath: destinationPath, date: Date(), documentID: documentID)
  }

  /// Where `url` lies, for messages: its inbox's label, else its archive folder's name ("Noten & Bücher"), else the
  /// name of the folder holding it.
  func placeName(ofFolderHolding url: URL) -> String {
    if let label = inboxLabel(ofFolderHolding: url) { return label }
    let folder = url.deletingLastPathComponent()
    if let root = folders.archiveRoot?.url,
      let path = DestinationIndex.archiveRelativePath(of: folder, under: root)
    {
      return ArchivePath.title(of: path)
    }
    return folder.lastPathComponent
  }

  /// The label of the configured inbox holding `url`, if one does.
  private func inboxLabel(ofFolderHolding url: URL) -> String? {
    InboxLocation.label(
      ofInboxHolding: url,
      among: folders.inboxes.compactMap { inbox in inbox.url.map { (inbox.displayLabel, $0) } })
  }

  /// Keep Both in the Move Back conflict alert: moves the file back under a numbered name beside the item in the way.
  func resolve(_ conflict: MoveBackConflict) {
    Task { await perform(conflict.request, resolution: .keepBoth) }
  }

  private func perform(_ request: MoveBackRequest, resolution: ConflictResolution) async {
    guard !isFilingInProgress else { return }
    isFilingInProgress = true
    defer { isFilingInProgress = false }
    let markBefore = inboxes.row(for: request.itemID)?.mark
    do {
      let outcome = try await filing.moveBack(
        document: request.documentID, at: request.url, resolution: resolution)
      inboxes.setMark(request.itemID, nil)
      registerUndo(
        of: .moveBack(request, resolution: resolution, markBefore: markBefore),
        ticket: FilingEventTicket(eventID: outcome.event.id))
      let returnedName = outcome.movedURL.lastPathComponent
      statusMessage = WindowStatusMessage(
        text: returnedName == request.originalName
          ? "Moved “\(request.originalName)” back to \(request.inboxName) · Undo ⌘Z"
          : "Moved “\(request.originalName)” back to \(request.inboxName) as \(returnedName) · Undo ⌘Z"
      )
      showReturned(request.itemID)
    } catch .fileOperation(.nameConflict(let existing)) {
      moveBackConflict = MoveBackConflict(blockingURL: existing, request: request)
    } catch {
      Logger.filing.error(
        "Moving \(request.originalName, privacy: .private) back failed: \(String(describing: error), privacy: .private)"
      )
      alert = FilingAlert(
        title: "“\(request.originalName)” can’t be moved back to \(request.inboxName)",
        message: FilingMessages.text(for: error))
    }
  }

  private func perform(_ request: PutBackRequest) async {
    guard !isFilingInProgress else { return }
    isFilingInProgress = true
    defer { isFilingInProgress = false }
    do {
      let outcome = try await filing.putBack(request.trashedURL)
      let returnedURL = outcome.restored.url
      let markAfter = mark(afterPutBackTo: returnedURL, documentID: outcome.documentID)
      inboxes.setMark(request.itemID, markAfter)
      registerUndo(
        of: .putBack(request, returnedTo: returnedURL, markAfter: markAfter),
        ticket: FilingEventTicket())
      statusMessage = WindowStatusMessage(
        text:
          "Put “\(returnedURL.lastPathComponent)” back in \(placeName(ofFolderHolding: returnedURL)) · Undo ⌘Z"
      )
      showReturned(request.itemID)
      // Resetting the panel to the same folder lists nothing new, so Folder contents is listed again.
      picker.reloadContents(selecting: returnedURL)
    } catch {
      Logger.filing.error(
        "Putting \(request.originalName, privacy: .private) back failed: \(String(describing: error), privacy: .private)"
      )
      alert = FilingAlert(
        title: "“\(request.originalName)” can’t be put back",
        message: FilingMessages.text(for: error))
    }
  }

  // MARK: Undo and redo

  /// Registers undoing `action` with the window's undo manager; `ticket` holds the event the undo acts on.
  ///
  /// Undo and redo run asynchronously, but the undo manager needs the opposite action registered while it is
  /// undoing or redoing; so each handler registers its counterpart at once and the counterpart reads the event it
  /// acts on from a ticket that the asynchronous work fills in.
  func registerUndo(of action: UndoableFiling, ticket: FilingEventTicket) {
    guard let undoManager else {
      Logger.filing.error(
        "No undo manager: \(action.actionName, privacy: .private) can't be undone")
      return
    }
    undoManager.registerUndo(withTarget: self) { model in
      let redoTicket = FilingEventTicket()
      model.registerRedo(of: action, ticket: redoTicket)
      Task { await model.undo(action, ticket: ticket, redoTicket: redoTicket) }
    }
    undoManager.setActionName(action.actionName)
  }

  /// Registers redoing `action`; `ticket` holds the event the redo acts on (only Put Back's redo needs one).
  private func registerRedo(of action: UndoableFiling, ticket: FilingEventTicket) {
    guard let undoManager else { return }
    undoManager.registerUndo(withTarget: self) { model in
      let undoTicket = FilingEventTicket()
      model.registerUndo(of: action, ticket: undoTicket)
      Task { await model.redo(action, ticket: ticket, undoTicket: undoTicket) }
    }
    undoManager.setActionName(action.actionName)
  }

  /// The event in `ticket`, or `nil` after telling the user that the step before has not finished yet.
  private func event(
    in ticket: FilingEventTicket, for action: UndoableFiling, step: String
  ) -> FilingEvent.ID? {
    guard let eventID = ticket.eventID else {
      alert = FilingAlert(
        title: "\(action.actionName) can’t be \(step)",
        message: "The action has not finished yet. Try again in a moment.")
      return nil
    }
    return eventID
  }

  private func undo(
    _ action: UndoableFiling, ticket: FilingEventTicket, redoTicket: FilingEventTicket
  ) async {
    do {
      let returnedRowID = action.itemID
      switch action {
      case .move(let request, _, let markBefore, let replacedRows):
        guard let eventID = event(in: ticket, for: action, step: "undone") else { return }
        _ = try await filing.undo(eventID: eventID)
        // Undoing a move removes the folders it created (when still empty); a rebuild keeps the old index in use
        // until the new one is ready, so it is cheap to do whenever a move is undone.
        archive.rebuild()
        inboxes.setMark(request.itemID, markBefore)
        // Undoing a Replace puts the replaced file back where it was filed.
        for replaced in replacedRows {
          inboxes.setMark(replaced.id, replaced.markBefore)
        }
      case .moveBack(let request, _, let markBefore):
        guard let eventID = event(in: ticket, for: action, step: "undone") else { return }
        // Rows follow the file's identity, so the request's row lists the file also under a numbered name.
        _ = try await inboxes.keepingRow(request.itemID) { () async throws(FilingError) in
          try await filing.undo(eventID: eventID)
        }
        archive.rebuild()
        inboxes.setMark(request.itemID, markBefore)
      case .trash(let request):
        guard let eventID = event(in: ticket, for: action, step: "undone") else { return }
        _ = try await filing.undo(eventID: eventID)
        inboxes.setMark(request.itemID, nil)
      case .putBack(let request, let returnedURL, _):
        let outcome = try await trashKeepingRow(request.itemID, url: returnedURL)
        redoTicket.eventID = outcome.event.id
        inboxes.setMark(
          request.itemID,
          .trashed(trashedURL: outcome.record.trashedURL, date: outcome.event.date))
      case .archiveRename(let request, let filedRows):
        guard let eventID = event(in: ticket, for: action, step: "undone") else { return }
        _ = try await filing.undo(eventID: eventID)
        restoreMarks(of: filedRows)
        picker.reloadContents(selecting: request.source)
      case .archiveTrash(let request, let filedRows):
        guard let eventID = event(in: ticket, for: action, step: "undone") else { return }
        _ = try await filing.undo(eventID: eventID)
        restoreMarks(of: filedRows)
        picker.reloadContents(selecting: request.url)
      }
      if let returnedRowID { showReturned(returnedRowID) }
      // The file left the folder Folder contents may show, which the panel reset doesn't list again.
      if case .putBack = action { picker.reloadContents(selecting: nil) }
      statusMessage = nil
    } catch {
      Logger.filing.error(
        "Undoing \(action.actionName, privacy: .private) failed: \(String(describing: error), privacy: .private)"
      )
      alert = FilingAlert(
        title: "\(action.actionName) can’t be undone", message: FilingMessages.text(for: error))
      // Registering the undo again replaces the redo registered for it, which would act on a file that never came
      // back, and lets the user try again.
      registerUndo(of: action, ticket: ticket)
    }
  }

  private func redo(
    _ action: UndoableFiling, ticket: FilingEventTicket, undoTicket: FilingEventTicket
  ) async {
    do {
      switch action {
      case .move(let request, let resolution, _, _):
        let outcome = try await moveFile(of: request, resolution: resolution)
        undoTicket.eventID = outcome.event.id
        if !outcome.record.createdFolders.isEmpty { archive.rebuild() }
        // The rows a Replace marks are the ones its undo restored, so the stored marks stay right.
        _ = applyMarks(of: outcome, for: request)
        finishMove(of: request)
      case .moveBack(let request, let resolution, _):
        let outcome = try await filing.moveBack(
          document: request.documentID, at: request.url, resolution: resolution)
        undoTicket.eventID = outcome.event.id
        inboxes.setMark(request.itemID, nil)
        showReturned(request.itemID)
      case .trash(let request):
        let outcome = try await trashKeepingRow(request.itemID, url: request.url)
        undoTicket.eventID = outcome.event.id
        inboxes.setMark(
          request.itemID,
          .trashed(trashedURL: outcome.record.trashedURL, date: outcome.event.date))
        finishHandling(request.itemID)
      case .putBack(let request, let returnedURL, let markAfter):
        guard let eventID = event(in: ticket, for: action, step: "redone") else { return }
        _ = try await filing.undo(eventID: eventID)
        inboxes.setMark(request.itemID, markAfter)
        showReturned(request.itemID)
        picker.reloadContents(selecting: returnedURL)
      case .archiveRename(let request, _):
        let outcome = try await filing.rename(request.source, to: request.name)
        undoTicket.eventID = outcome.event.id
        applyRename(outcome)
      case .archiveTrash(let request, _):
        let outcome = try await filing.trash(request.url)
        undoTicket.eventID = outcome.event.id
        applyTrash(outcome, selectingAfterwards: request.selectionAfter)
      }
    } catch {
      Logger.filing.error(
        "Redoing \(action.actionName, privacy: .private) failed: \(String(describing: error), privacy: .private)"
      )
      alert = FilingAlert(
        title: "\(action.actionName) can’t be redone", message: FilingMessages.text(for: error))
      undoManager?.removeAllActions(withTarget: self)
    }
  }

  // MARK: History

  /// Tries the pending history save again.
  func retryHistorySave() {
    Task { await filing.retrySave() }
  }

  /// Sets the unreadable history aside and starts a new one.
  func startNewHistory() {
    Task {
      do throws(FilingError) {
        try await filing.startNewHistory()
      } catch {
        alert = FilingAlert(
          title: "A new filing history could not be started",
          message: FilingMessages.text(for: error))
      }
    }
  }
}
