import SwiftUI

/// The main window's menu-bar commands: Open and Reveal in Finder (File), the filing panel toggle and the preview zoom
/// (View), the sidebar toggle, and History (Window).
///
/// The file and view commands act on the key main window through the `mainWindowModel` focused value and are
/// disabled when it is not key or when they do not apply. History is always available.
struct MainCommands: Commands {
  @FocusedValue(\.mainWindowModel) private var mainWindowModel
  @Environment(\.openWindow) private var openWindow

  var body: some Commands {
    SidebarCommands()

    CommandGroup(after: .newItem) {
      Button("Open") {
        if let selectedFile { FileActions.open(selectedFile.url) }
      }
      .keyboardShortcut("o")
      .disabled(selectedFile == nil)

      Button("Reveal in Finder") {
        if let selectedFile { FileActions.revealInFinder(selectedFile.url) }
      }
      .keyboardShortcut("r", modifiers: [.option, .command])
      .disabled(selectedFile == nil)
    }

    CommandGroup(after: .sidebar) {
      Button(filingPanelToggleTitle) {
        mainWindowModel?.isFilingPanelShown.toggle()
      }
      .keyboardShortcut("i", modifiers: [.option, .command])
      .disabled(mainWindowModel == nil)

      Divider()

      Button("Zoom In") {
        previewController?.zoomIn()
      }
      .keyboardShortcut("+")
      .disabled(!(previewController?.canZoomIn ?? false))

      Button("Zoom Out") {
        previewController?.zoomOut()
      }
      .keyboardShortcut("-")
      .disabled(!(previewController?.canZoomOut ?? false))

      Button("Zoom to Fit") {
        previewController?.zoomToFit()
      }
      .keyboardShortcut("0")
      .disabled(!(previewController?.canZoomToFit ?? false))
    }

    CommandGroup(after: .singleWindowList) {
      Button("History") {
        openWindow(id: SceneID.history)
      }
      .keyboardShortcut("y")
    }
  }

  /// The file selected in the key main window.
  private var selectedFile: SelectedFile? {
    mainWindowModel?.selectedFile
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
