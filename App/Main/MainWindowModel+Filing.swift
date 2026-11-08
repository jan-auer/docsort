import DocsortCore
import Foundation
import OSLog

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

/// A name conflict waiting for the user's choice between Keep Both, Replace and Cancel.
nonisolated struct FilingConflict: Identifiable, Sendable {
  /// Distinguishes this conflict from the previous one.
  let id = UUID()
  /// The name of the item already in the destination.
  let existingName: String
  /// The move that ran into it.
  let request: MoveRequest
}

/// An action on the window's undo stack.
nonisolated private enum UndoableFiling: Sendable {
  /// A move, redone with `resolution` (Replace again, or refuse a conflict).
  case move(MoveRequest, resolution: ConflictResolution)
  /// A move to the Trash.
  case trash(TrashRequest)

  var itemID: InboxItemID {
    switch self {
    case .move(let request, _): request.itemID
    case .trash(let request): request.itemID
    }
  }

  /// The Edit menu's name for the action.
  var actionName: String {
    switch self {
    case .move(let request, _): "Move of “\(request.originalName)”"
    case .trash(let request): "Move to Trash of “\(request.originalName)”"
    }
  }
}

/// The history event an undo entry undoes; filled in when a redo completes, after the entry was registered.
private final class FilingEventTicket {
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
    }
  }

  // MARK: Moving

  /// Whether the selected file can be moved: an unhandled, complete file, with the archive available and the history
  /// writable.
  var canMoveSelectedFile: Bool {
    guard let file = selectedFile, file.mark == nil, file.completeness == .complete else {
      return false
    }
    return archiveAvailability == .available && filing.isHistoryWritable && !isFilingInProgress
  }

  /// The name the selected file would be filed under, from the name field.
  var finalName: String? {
    guard let file = selectedFile else { return nil }
    return FileNaming.finalName(entered: panel.nameText, originalName: file.originalName)
  }

  /// File › Move (⌘Return) and the Move button: moves the selected file to the chosen destination under the
  /// entered name.
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

  /// Moves the selected file into `destination` under the entered name.
  private func move(to destination: PickerDestination) {
    guard canMoveSelectedFile, let file = selectedFile, let index = archive.index else { return }
    let name = FileNaming.finalName(entered: panel.nameText, originalName: file.originalName)
    guard FileNaming.validationProblem(for: name) == nil else {
      requestFocus(.nameField)
      return
    }
    let request = MoveRequest(
      itemID: file.id, source: file.url, folderURL: index.url(for: destination.path),
      archivePath: destination.path, name: name, originalName: file.originalName)
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
    do {
      let outcome = try await filing.file(
        request.source, into: request.folderURL, archivePath: request.archivePath,
        named: request.name, resolution: resolution)
      inboxes.markFiled(
        request.itemID, newURL: outcome.movedURL, destinationPath: request.archivePath)
      if !outcome.record.createdFolders.isEmpty { archive.rebuild() }
      let filedName = outcome.movedURL.lastPathComponent
      let redoRequest = MoveRequest(
        itemID: request.itemID, source: request.source, folderURL: request.folderURL,
        archivePath: request.archivePath, name: filedName, originalName: request.originalName)
      registerUndo(
        of: .move(redoRequest, resolution: resolution == .replace ? .replace : .refuse),
        ticket: FilingEventTicket(eventID: outcome.event.id))
      statusMessage = WindowStatusMessage(
        text: "Moved to \(request.archivePath) as \(filedName) · Undo ⌘Z")
      finishHandling(request.itemID)
    } catch .fileOperation(.nameConflict(let existing)) {
      conflict = FilingConflict(existingName: existing.lastPathComponent, request: request)
    } catch {
      Logger.filing.error(
        "Moving \(request.originalName, privacy: .private) failed: \(String(describing: error), privacy: .private)"
      )
      panel.notice = FilingMessages.text(for: error)
    }
  }

  // MARK: Trashing

  /// Whether the selected file can be moved to the Trash: an unhandled file, with the history writable.
  var canTrashSelectedFile: Bool {
    guard let file = selectedFile, file.mark == nil else { return false }
    return filing.isHistoryWritable && !isFilingInProgress
  }

  /// File › Move to Trash (⌘⌫): moves the selected file to the Trash, without confirmation (it can be undone).
  func trashSelectedFile() {
    guard canTrashSelectedFile, let file = selectedFile else { return }
    let request = TrashRequest(itemID: file.id, url: file.url, originalName: file.originalName)
    Task { await perform(request) }
  }

  private func perform(_ request: TrashRequest) async {
    guard !isFilingInProgress else { return }
    isFilingInProgress = true
    defer { isFilingInProgress = false }
    do {
      let outcome = try await filing.trash(request.url)
      inboxes.markTrashed(request.itemID)
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

  /// After a file was handled: selects the next unhandled file, resets the panel and returns focus to the sidebar.
  private func finishHandling(_ id: InboxItemID) {
    if let next = inboxes.nextUnhandledRow(after: id) {
      select(next.id)
    }
    resetPanel()
    requestFocus(.sidebar)
  }

  // MARK: Undo and redo

  /// Registers undoing `action` (the event in `ticket`) with the window's undo manager.
  ///
  /// Undo and redo run asynchronously, but the undo manager needs the opposite action registered while it is
  /// undoing or redoing; so each handler registers its counterpart at once and the counterpart reads the event it
  /// acts on from a ticket that the asynchronous work fills in.
  private func registerUndo(of action: UndoableFiling, ticket: FilingEventTicket) {
    guard let undoManager else {
      Logger.filing.error(
        "No undo manager: \(action.actionName, privacy: .private) can't be undone")
      return
    }
    undoManager.registerUndo(withTarget: self) { model in
      model.registerRedo(of: action)
      Task { await model.undo(action, ticket: ticket) }
    }
    undoManager.setActionName(action.actionName)
  }

  private func registerRedo(of action: UndoableFiling) {
    guard let undoManager else { return }
    let ticket = FilingEventTicket()
    undoManager.registerUndo(withTarget: self) { model in
      model.registerUndo(of: action, ticket: ticket)
      Task { await model.redo(action, ticket: ticket) }
    }
    undoManager.setActionName(action.actionName)
  }

  private func undo(_ action: UndoableFiling, ticket: FilingEventTicket) async {
    guard let eventID = ticket.eventID else {
      alert = FilingAlert(
        title: "\(action.actionName) can’t be undone",
        message: "The action has not finished yet. Try again in a moment.")
      return
    }
    do {
      _ = try await filing.undo(eventID: eventID)
      // Undoing a move removes the folders it created (when still empty); a rebuild keeps the old index in use
      // until the new one is ready, so it is cheap to do whenever a move is undone.
      if case .move = action { archive.rebuild() }
      inboxes.unmark(action.itemID)
      select(action.itemID)
      resetPanel()
      statusMessage = nil
      requestFocus(.sidebar)
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

  private func redo(_ action: UndoableFiling, ticket: FilingEventTicket) async {
    do {
      switch action {
      case .move(let request, let resolution):
        let outcome = try await filing.file(
          request.source, into: request.folderURL, archivePath: request.archivePath,
          named: request.name, resolution: resolution)
        ticket.eventID = outcome.event.id
        if !outcome.record.createdFolders.isEmpty { archive.rebuild() }
        inboxes.markFiled(
          request.itemID, newURL: outcome.movedURL, destinationPath: request.archivePath)
      case .trash(let request):
        let outcome = try await filing.trash(request.url)
        ticket.eventID = outcome.event.id
        inboxes.markTrashed(request.itemID)
      }
      finishHandling(action.itemID)
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
