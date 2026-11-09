import SwiftUI

/// The main window's menu-bar commands: Open, Reveal in Finder, Open Destination in Finder, Move, Revert Name, Move
/// to Trash and Move Back to Inbox (Put Back for a trashed file) (File), Refresh, the filing panel toggle and the
/// preview zoom (View), the sidebar toggle, Previous File and Next File (Go), History (Window) and Keyboard Shortcuts
/// (Help). Undo and Redo (Edit) come from the window's undo manager. Every shortcut comes from `MenuCommand`, which
/// the keyboard shortcuts sheet lists.
///
/// The file and view commands act on the key main window through the `mainWindowModel` focused value and are
/// disabled when it is not key or when they do not apply. History is always available; Keyboard Shortcuts toggles
/// the sheet over the key main window.
struct MainCommands: Commands {
  @FocusedValue(\.mainWindowModel) private var mainWindowModel
  @FocusedValue(\.keyboardShortcutsSheet) private var keyboardShortcutsSheet
  @Environment(\.openWindow) private var openWindow

  var body: some Commands {
    SidebarCommands()

    CommandGroup(after: .newItem) {
      Button("Open") {
        if let selectedFile { FileActions.open(selectedFile.url) }
      }
      .keyboardShortcut(for: .open)
      .disabled(selectedFile == nil)

      Button("Reveal in Finder") {
        if let selectedFile { FileActions.revealInFinder(selectedFile.url) }
      }
      .keyboardShortcut(for: .revealInFinder)
      .disabled(selectedFile == nil)

      // The filing panel's chosen or highlighted folder.
      Button("Open Destination in Finder") {
        if let destinationFolder { FileActions.open(destinationFolder) }
      }
      .keyboardShortcut(for: .openDestinationInFinder)
      .disabled(destinationFolder == nil)

      Divider()

      Button("Move") {
        mainWindowModel?.moveSelectedFile()
      }
      .keyboardShortcut(for: .move)
      .disabled(!(mainWindowModel?.canMoveSelectedFile ?? false))

      Button("Revert Name") {
        mainWindowModel?.revertName()
      }
      .keyboardShortcut(for: .revertName)
      .disabled(!(mainWindowModel?.canRevertName ?? false))

      // Disabled while a text field has focus, so ⌘⌫ deletes text there instead of trashing the file.
      Button("Move to Trash") {
        mainWindowModel?.trashSelectedFile()
      }
      .keyboardShortcut(for: .moveToTrash)
      .disabled(
        !(mainWindowModel?.canTrashSelectedFile ?? false)
          || (mainWindowModel?.isTextFieldFocused ?? false))

      Button(returnToInboxTitle) {
        mainWindowModel?.returnSelectedFileToInbox()
      }
      .keyboardShortcut(for: .returnToInbox)
      .disabled(!(mainWindowModel?.canReturnSelectedFileToInbox ?? false))
    }

    CommandGroup(after: .sidebar) {
      // Lists the inboxes again and rebuilds the archive's folder index.
      Button("Refresh") {
        mainWindowModel?.refresh()
      }
      .keyboardShortcut(for: .refresh)
      .disabled(mainWindowModel == nil)

      Button(filingPanelToggleTitle) {
        mainWindowModel?.isFilingPanelShown.toggle()
      }
      .keyboardShortcut(for: .toggleFilingPanel)
      .disabled(mainWindowModel == nil)

      Divider()

      Button("Zoom In") {
        previewController?.zoomIn()
      }
      .keyboardShortcut(for: .zoomIn)
      .disabled(!(previewController?.canZoomIn ?? false))

      Button("Zoom Out") {
        previewController?.zoomOut()
      }
      .keyboardShortcut(for: .zoomOut)
      .disabled(!(previewController?.canZoomOut ?? false))

      Button("Zoom to Fit") {
        previewController?.zoomToFit()
      }
      .keyboardShortcut(for: .zoomToFit)
      .disabled(!(previewController?.canZoomToFit ?? false))
    }

    CommandMenu("Go") {
      Button("Previous File") {
        mainWindowModel?.selectFile(.previous)
      }
      .keyboardShortcut(for: .previousFile)
      .disabled(mainWindowModel?.file(.previous) == nil)

      Button("Next File") {
        mainWindowModel?.selectFile(.next)
      }
      .keyboardShortcut(for: .nextFile)
      .disabled(mainWindowModel?.file(.next) == nil)
    }

    CommandGroup(after: .singleWindowList) {
      Button("History") {
        openWindow(id: SceneID.history)
      }
      .keyboardShortcut(for: .history)
    }

    CommandGroup(after: .help) {
      Button("Keyboard Shortcuts") {
        keyboardShortcutsSheet?.wrappedValue.toggle()
      }
      .keyboardShortcut(for: .keyboardShortcuts)
      .disabled(keyboardShortcutsSheet == nil)
    }
  }

  /// The file selected in the key main window.
  private var selectedFile: SelectedFile? {
    mainWindowModel?.selectedFile
  }

  /// Where the folder the key main window's filing panel would file into (chosen, else highlighted) is on disk; `nil`
  /// while the panel is hidden or does not take a destination for the selected file, and for a pending new folder.
  private var destinationFolder: URL? {
    guard let mainWindowModel, mainWindowModel.isFilingPanelShown,
      mainWindowModel.canChooseDestination
    else { return nil }
    return mainWindowModel.picker.destinationFolderURL
  }

  /// The title of the command returning the selected file to its inbox: "Put Back" for a trashed file, "Move Back to
  /// Inbox" otherwise.
  private var returnToInboxTitle: LocalizedStringKey {
    if mainWindowModel?.selectedReturnToInboxAction == .putBack {
      "Put Back"
    } else {
      "Move Back to Inbox"
    }
  }

  /// The filing panel toggle's title, which names what the command will do.
  private var filingPanelToggleTitle: LocalizedStringKey {
    if mainWindowModel?.isFilingPanelShown == false {
      "Show Filing Panel"
    } else {
      "Hide Filing Panel"
    }
  }

  /// The preview controller of the key main window.
  private var previewController: PreviewController? {
    mainWindowModel?.previewController
  }
}
