import DocsortCore
import Foundation

/// What the Folders pane can ask for, as closures, so that its views render from plain values in previews.
struct FolderSettingsActions {
  /// Picks the archive folder.
  var chooseArchiveRoot: () -> Void
  /// Picks a folder and adds it as an inbox at the end.
  var addInbox: () -> Void
  /// Removes the inbox with the id; its files are untouched.
  var removeInbox: (InboxFolder.ID) -> Void
  /// Sets the inbox's label; blank shows the folder name.
  var relabelInbox: (InboxFolder.ID, String) -> Void
  /// Moves inboxes as a list's `onMove` does.
  var moveInboxes: (IndexSet, Int) -> Void
  /// Picks a new folder for the inbox with the id.
  var chooseInboxFolder: (InboxFolder.ID) -> Void
  /// Forgets the stored folder settings.
  var resetFolderSettings: () -> Void

  /// The actions of `folders`, with folders picked through `FolderChooser`.
  init(folders: FolderLibrary) {
    let chooser = FolderChooser(folders: folders)
    chooseArchiveRoot = { chooser.chooseArchiveRoot() }
    addInbox = { chooser.chooseNewInbox() }
    removeInbox = { folders.removeInbox(id: $0) }
    relabelInbox = { folders.relabelInbox(id: $0, to: $1) }
    moveInboxes = { folders.moveInboxes(fromOffsets: $0, toOffset: $1) }
    chooseInboxFolder = { chooser.chooseFolder(forInbox: $0) }
    resetFolderSettings = { folders.resetFolderSettings() }
  }

  #if DEBUG
    /// Actions that do nothing, for previews.
    static let none = FolderSettingsActions()

    private init() {
      chooseArchiveRoot = {}
      addInbox = {}
      removeInbox = { _ in }
      relabelInbox = { _, _ in }
      moveInboxes = { _, _ in }
      chooseInboxFolder = { _ in }
      resetFolderSettings = {}
    }
  #endif
}
