import DocsortCore
import Foundation
import OSLog

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
        inboxes.setMark(request.itemID, .trashed(by: outcome))
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
        inboxes.setMark(request.itemID, .trashed(by: outcome))
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
}
