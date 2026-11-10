import DocsortCore
import Foundation

/// The new-folder row (``DestinationPickerModel/newFolderDraft``) and the create row: opening, naming, confirming and
/// cancelling a new folder.
extension DestinationPickerModel {
  /// The folder ``beginNewFolder()`` would create a folder in, for the button's tooltip "New Folder in Reisen":
  /// ``ArchivePath/rootTitle`` for the root.
  var newFolderParentTitle: String {
    ArchivePath.title(of: newFolderParent)
  }

  /// ⇧⌘N or the New Folder button. With the create row highlighted, creates its folder at once (as choosing it).
  /// Otherwise opens the new-folder row in ``newFolderParentTitle``'s folder: the chosen destination if it exists,
  /// else the highlighted folder row if it is not new, else the scope. The view then focuses
  /// ``PickerField/newFolderName``.
  func beginNewFolder() {
    guard newFolderDraft == nil else { return }
    if destination == nil, case .createFolder = highlightedRow?.kind {
      confirmCreateRow()
      return
    }
    let parent = newFolderParent
    stateBeforeDraft = StateBeforeDraft(
      scope: scope, query: query, highlightedRowID: highlightedRowID, destination: destination)
    destination = nil
    scope = parent
    query = ""
    newFolderDraft = NewFolderDraft(parent: parent, name: "", notice: nil)
    update(highlight: .currentFolder)
  }

  /// ⇧⌘N or a click on the highlighted create row: chooses the folder it offers (pending until the move) and emits
  /// ``PickerEvent/chose(_:)``. Does nothing when the create row is not highlighted or its name is invalid.
  func confirmCreateRow() {
    guard let created = highlightedCreateRowDestination else { return }
    choose(created)
    onEvent(.chose(created))
  }

  /// The name typed into the new-folder row, bound to its field; setting it updates the row's notice. The row stays
  /// where it is, directly under its parent.
  var newFolderName: String {
    get { newFolderDraft?.name ?? "" }
    set {
      guard var draft = newFolderDraft else { return }
      draft.name = newValue
      draft.notice = notice(for: draft)
      newFolderDraft = draft
      update(highlight: .keep)
    }
  }

  /// Confirms the new-folder row: chooses the folder the name gives and emits `event` with it,
  /// ``PickerEvent/chose(_:)`` for Tab or Return, ``PickerEvent/moveRequested(_:)`` for ⌘Return. A new folder becomes
  /// pending; a name that exists (ignoring case) chooses the existing folder. An empty name cancels the row.
  ///
  /// - Returns: `false` when the row stays because the name is invalid (or there is no row); `true` when it ended,
  ///   chosen or cancelled.
  @discardableResult
  func confirmNewFolder(reporting event: (PickerDestination) -> PickerEvent) -> Bool {
    guard let draft = newFolderDraft else { return false }
    let typed = NewFolderPath(typed: draft.name)
    guard
      let chosen = typed.resolved(under: draft.parent, index: index, pendingFolders: pendingFolders)
    else {
      cancelNewFolder()
      return true
    }
    guard typed.problem == nil else { return false }
    lastDraftEnding = .chosen
    newFolderDraft = nil
    stateBeforeDraft = nil
    scope = draft.parent
    query = ""
    choose(chosen)
    onEvent(event(chosen))
    return true
  }

  /// Esc or ⇧Tab in the new-folder row: removes it and restores the filter, scope, highlight and destination from
  /// before it opened. Does nothing without a row.
  func cancelNewFolder() {
    guard newFolderDraft != nil, let saved = stateBeforeDraft else { return }
    lastDraftEnding = .cancelled
    newFolderDraft = nil
    stateBeforeDraft = nil
    scope = saved.scope
    query = saved.query
    destination = saved.destination
    highlightedRowID = saved.highlightedRowID
    update(highlight: .keep)
  }

  /// What ``cancelNewFolder()`` restores.
  struct StateBeforeDraft {
    let scope: String
    let query: String
    let highlightedRowID: PickerRow.ID?
    let destination: PickerDestination?
  }

  /// The notice the new-folder row shows for `draft`'s name.
  func notice(for draft: NewFolderDraft) -> NewFolderNotice? {
    let typed = NewFolderPath(typed: draft.name)
    if let problem = typed.problem { return .invalid(problem) }
    guard
      let resolved = typed.resolved(
        under: draft.parent, index: index, pendingFolders: pendingFolders),
      let relativePath = ArchivePath.relative(resolved.path, to: draft.parent)
    else { return nil }
    if case .folder = resolved {
      return .existing(parentTitle: ArchivePath.title(of: draft.parent), existingName: relativePath)
    }
    let components = ArchivePath.segments(of: relativePath)
    return components.count > 1 ? .nested(components) : nil
  }

  /// The parent ``beginNewFolder()`` uses; see there.
  private var newFolderParent: String {
    if case .folder(let path) = destination, index?.contains(path) == true { return path }
    if case .folder(let folder) = highlightedRow?.kind, !folder.isNew { return folder.path }
    return scope
  }

  /// The folder the highlighted create row would create (not yet pending); `nil` when the create row is not
  /// highlighted or its name is invalid.
  private var highlightedCreateRowDestination: PickerDestination? {
    guard case .createFolder(let name, let parent, let problem) = highlightedRow?.kind,
      problem == nil
    else { return nil }
    return NewFolderPath(typed: name).resolved(
      under: parent, index: index, pendingFolders: pendingFolders)
  }
}

/// How a new-folder row ended.
enum NewFolderDraftEnding: Hashable, Sendable {
  /// Its folder was chosen (Tab, Return or ⌘Return).
  case chosen
  /// It was cancelled (Esc, ⇧Tab, an empty name, or another action that closes it).
  case cancelled
}
