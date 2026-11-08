import AppKit
import DocsortCore

/// Lets the user pick folders for a `FolderLibrary` with the system's open panel, and hands each picked folder to it.
///
/// This is the view side of folder editing: the library holds the logic and never touches AppKit. In the sandbox the
/// panel is what grants the app access to the folder, and the grant lasts while the app runs, so the library makes
/// the folder's bookmark straight away, while the grant is live.
struct FolderChooser {
  /// The library that receives the picked folders.
  let folders: FolderLibrary

  /// Asks for the archive folder and makes it the archive root.
  func chooseArchiveRoot() {
    guard
      let folder = Self.pickFolder(
        message: "Choose the archive folder that documents are filed into.",
        startingAt: folders.archiveRootPickerStart)
    else { return }
    folders.setArchiveRoot(to: folder)
  }

  /// Asks for a folder and adds it as an inbox at the end of the sidebar.
  func chooseNewInbox() {
    guard
      let folder = Self.pickFolder(
        message: "Choose an inbox folder with documents to file.",
        startingAt: folders.newInboxPickerStart)
    else { return }
    folders.addInbox(folder: folder)
  }

  /// Asks for a new folder for the inbox with `id`, for example one whose folder was moved or is stale.
  func chooseFolder(forInbox id: InboxFolder.ID) {
    guard let inbox = folders.inboxes.first(where: { $0.id == id }) else { return }
    guard
      let folder = Self.pickFolder(
        message: "Choose the folder for the inbox “\(inbox.displayLabel)”.",
        startingAt: folders.pickerStart(forInbox: id))
    else { return }
    folders.replaceFolder(ofInbox: id, with: folder)
  }

  /// Shows the open panel for a single folder (no files) and returns the chosen folder, or `nil` when the user
  /// cancels. `message` says what the folder is for; the panel starts in `startingFolder` when it is given.
  private static func pickFolder(message: String, startingAt startingFolder: URL?) -> URL? {
    let panel = NSOpenPanel()
    panel.canChooseFiles = false
    panel.canChooseDirectories = true
    panel.allowsMultipleSelection = false
    panel.canCreateDirectories = true
    panel.prompt = "Choose"
    panel.message = message
    panel.directoryURL = startingFolder
    guard panel.runModal() == .OK else { return nil }
    return panel.url
  }
}
