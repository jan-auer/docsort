import DocsortCore
import Foundation
import OSLog

extension InboxItemMark {
  /// The mark of a file that `outcome`'s move to the Trash put there.
  static func trashed(by outcome: TrashOutcome) -> InboxItemMark {
    .trashed(trashedURL: outcome.record.trashedURL, date: outcome.event.date)
  }
}

extension MainWindowModel {
  // MARK: Destinations

  /// Starts the destination filter with `text` typed in the sidebar and moves focus there.
  ///
  /// A new search starts at the archive root; keys typed before the filter has taken focus are appended.
  func startDestinationFilter(with text: String) {
    if !picker.hasTextTypedBeforeFocus { picker.reset() }
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

  /// Runs `operation`, a move, trash, Move Back, Put Back or archive file change, unless another one is under way
  /// (then it is dropped); `isFilingInProgress` is set while it runs.
  func startFilingOperation(_ operation: @escaping @MainActor () async -> Void) {
    Task {
      guard !isFilingInProgress else { return }
      isFilingInProgress = true
      defer { isFilingInProgress = false }
      await operation()
    }
  }

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
    startFilingOperation { await self.perform(request, resolution: .refuse) }
  }

  /// Retries the move of `conflict` with `resolution` (Keep Both or Replace).
  func resolve(_ conflict: FilingConflict, with resolution: ConflictResolution) {
    startFilingOperation { await self.perform(conflict.request, resolution: resolution) }
  }

  /// Cancels the move of a conflict and returns to the name field.
  func cancelConflict() {
    requestFocus(.nameField)
  }

  private func perform(_ request: MoveRequest, resolution: ConflictResolution) async {
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
      statusMessage = .undoable(
        request.kind.isRenaming
          ? "Renamed to \(filedName)"
          : "Moved to \(request.archivePath) as \(filedName)")
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
  ///
  /// Like the other step helpers here (`applyMarks`, `finishMove`, `trashKeepingRow`, `finishHandling`,
  /// `showReturned`), it skips the `isFilingInProgress` guard of `startFilingOperation`: it is internal only for
  /// undo and redo (`MainWindowModel+Undo.swift`), which run outside that guard.
  func moveFile(
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
  func applyMarks(of outcome: MoveOutcome, for request: MoveRequest) -> [MarkedRow] {
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
  func finishMove(of request: MoveRequest) {
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
    startFilingOperation { await self.perform(request) }
  }

  private func perform(_ request: TrashRequest) async {
    do {
      let outcome = try await trashKeepingRow(request.itemID, url: request.url)
      inboxes.setMark(request.itemID, .trashed(by: outcome))
      registerUndo(of: .trash(request), ticket: FilingEventTicket(eventID: outcome.event.id))
      statusMessage = .undoable("Moved “\(request.originalName)” to the Trash")
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
  func trashKeepingRow(_ id: InboxItemID, url: URL) async throws(FilingError)
    -> TrashOutcome
  {
    try await inboxes.keepingRow(id) { () async throws(FilingError) in
      try await filing.trash(url)
    }
  }

  /// After a file was handled: selects the next unhandled file, resets the panel and returns focus to the sidebar.
  func finishHandling(_ id: InboxItemID) {
    if let next = inboxes.nextUnhandledRow(after: id) {
      select(next.id)
    }
    resetPanel()
    requestFocus(.sidebar)
  }

  /// After a file changed in place (renamed, moved back, put back, or an undo): selects it, resets the panel for it
  /// and returns focus to the sidebar.
  func showReturned(_ id: InboxItemID) {
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
      startFilingOperation { await self.perform(request, resolution: .refuse) }
    case .trashed(let trashedURL, _):
      let request = PutBackRequest(
        itemID: file.id, trashedURL: trashedURL, originalName: file.originalName)
      startFilingOperation { await self.perform(request) }
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
    startFilingOperation { await self.perform(conflict.request, resolution: .keepBoth) }
  }

  private func perform(_ request: MoveBackRequest, resolution: ConflictResolution) async {
    let markBefore = inboxes.row(for: request.itemID)?.mark
    do {
      let outcome = try await filing.moveBack(
        document: request.documentID, at: request.url, resolution: resolution)
      inboxes.setMark(request.itemID, nil)
      registerUndo(
        of: .moveBack(request, resolution: resolution, markBefore: markBefore),
        ticket: FilingEventTicket(eventID: outcome.event.id))
      let returnedName = outcome.movedURL.lastPathComponent
      statusMessage = .undoable(
        returnedName == request.originalName
          ? "Moved “\(request.originalName)” back to \(request.inboxName)"
          : "Moved “\(request.originalName)” back to \(request.inboxName) as \(returnedName)"
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
    do {
      let outcome = try await filing.putBack(request.trashedURL)
      let returnedURL = outcome.restored.url
      let markAfter = mark(afterPutBackTo: returnedURL, documentID: outcome.documentID)
      inboxes.setMark(request.itemID, markAfter)
      registerUndo(
        of: .putBack(request, returnedTo: returnedURL, markAfter: markAfter),
        ticket: FilingEventTicket())
      statusMessage = .undoable(
        "Put “\(returnedURL.lastPathComponent)” back in \(placeName(ofFolderHolding: returnedURL))"
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
