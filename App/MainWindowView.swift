import DocsortCore
import SwiftUI

/// The content of the main window: the inbox sidebar, the preview and the filing panel as an inspector, with the
/// selected file's name and actions in the toolbar.
///
/// The detail column shows the welcome view until folders are configured, then the selected file's preview, or a
/// quiet "No file selected" while nothing is selected, with the bottom bar (confirmations, history save warning)
/// under it. Name conflicts and failed actions are shown as alerts. Below `MainWindowModel.sidebarCollapseWidth` the sidebar
/// collapses first, so the preview keeps its room.
struct MainWindowView: View {
  /// The window's state.
  @Bindable var model: MainWindowModel

  @Environment(\.undoManager) private var undoManager

  var body: some View {
    NavigationSplitView(columnVisibility: $model.columnVisibility) {
      SidebarColumn {
        if model.areFoldersConfigured {
          InboxSidebar(model: model)
        }
      }
      .navigationSplitViewColumnWidth(min: 200, ideal: 260, max: 400)
    } detail: {
      VStack(spacing: 0) {
        detailColumn
          .frame(maxHeight: .infinity)
        WindowBottomBar(model: model)
      }
      .frame(minWidth: 420, maxWidth: .infinity, maxHeight: .infinity)
      .toolbar { fileToolbar }
    }
    .inspector(isPresented: $model.isFilingPanelShown) {
      FilingPanel(
        model: model,
        locateArchive: { FolderChooser(folders: model.folders).chooseArchiveRoot() }
      )
      .inspectorColumnWidth(min: 280, ideal: 340, max: 480)
    }
    .toolbar(removing: .title)
    .frame(minWidth: 1000, minHeight: 640)
    .onGeometryChange(for: MainWindowWidthClass.self) { geometry in
      geometry.size.width < MainWindowModel.sidebarCollapseWidth ? .narrow : .regular
    } action: { widthClass in
      model.windowWidthClassChanged(to: widthClass)
    }
    .onAppear { model.undoManager = undoManager }
    .onChange(of: undoManager) { _, undoManager in model.undoManager = undoManager }
    .folderSettingsAlert(for: model.folders)
    .alert(
      conflictTitle, isPresented: isConflictPresented, presenting: model.conflict
    ) { conflict in
      Button("Keep Both") { model.resolve(conflict, with: .keepBoth) }
        .keyboardShortcut(.defaultAction)
      Button("Replace", role: .destructive) { model.resolve(conflict, with: .replace) }
      Button("Cancel", role: .cancel) { model.cancelConflict() }
    } message: { _ in
      Text("Replace moves the existing file to the Trash.")
    }
    .alert(
      moveBackConflictTitle, isPresented: isMoveBackConflictPresented,
      presenting: model.moveBackConflict
    ) { conflict in
      Button("Keep Both") { model.resolve(conflict) }
        .keyboardShortcut(.defaultAction)
      Button("Cancel", role: .cancel) { model.requestFocus(.sidebar) }
    } message: { conflict in
      Text(
        "Something else is now at \(DisplayPath.abbreviating(conflict.blockingURL.path(percentEncoded: false))). Keep Both moves the file back under a numbered name."
      )
    }
    .alert(
      model.alert?.title ?? "", isPresented: isAlertPresented, presenting: model.alert
    ) { _ in
      Button("OK", role: .cancel) {}
    } message: { alert in
      Text(alert.message)
    }
    .focusedSceneValue(\.mainWindowModel, model)
    .accessibilityElement(children: .contain)
    .accessibilityIdentifier("main-window")
  }

  private var conflictTitle: String {
    guard let conflict = model.conflict else { return "" }
    return "“\(conflict.existingName)” already exists in \(conflict.request.archivePath)."
  }

  private var isConflictPresented: Binding<Bool> {
    Binding {
      model.conflict != nil
    } set: {
      if !$0 { model.conflict = nil }
    }
  }

  private var moveBackConflictTitle: String {
    guard let conflict = model.moveBackConflict else { return "" }
    return "“\(conflict.request.originalName)” can’t be moved back to \(conflict.request.inboxName)"
  }

  private var isMoveBackConflictPresented: Binding<Bool> {
    Binding {
      model.moveBackConflict != nil
    } set: {
      if !$0 { model.moveBackConflict = nil }
    }
  }

  private var isAlertPresented: Binding<Bool> {
    Binding {
      model.alert != nil
    } set: {
      if !$0 { model.alert = nil }
    }
  }

  @ViewBuilder private var detailColumn: some View {
    if !model.areFoldersConfigured {
      WelcomeView()
    } else if let selectedFile = model.selectedFile {
      PreviewView(document: selectedFile.previewDocument, controller: model.previewController)
    } else {
      ContentUnavailableView("No file selected", systemImage: "doc")
        .accessibilityIdentifier("no-selection")
    }
  }

  /// The toolbar title's tooltip: the inbox and name, and where a filed file went.
  private func toolbarHelp(for file: SelectedFile) -> String {
    guard case .filed(_, let destinationPath, _, _) = file.mark else {
      return "\(file.inboxName) › \(file.originalName)"
    }
    return "\(file.inboxName) › \(file.originalName) → \(destinationPath)/\(file.name)"
  }

  /// The selected file's inbox and name, its actions, and the filing panel toggle.
  @ToolbarContentBuilder private var fileToolbar: some ToolbarContent {
    ToolbarItem(placement: .navigation) {
      if let selectedFile = model.selectedFile {
        Text("\(selectedFile.inboxName) › \(selectedFile.name)")
          .lineLimit(1)
          .truncationMode(.middle)
          .frame(minWidth: 120, maxWidth: 480, alignment: .leading)
          .help(toolbarHelp(for: selectedFile))
          .accessibilityIdentifier("toolbar-file-title")
      }
    }
    ToolbarItemGroup(placement: .primaryAction) {
      Button {
        if let selectedFile = model.selectedFile { FileActions.open(selectedFile.url) }
      } label: {
        Label("Open", systemImage: "arrow.up.forward.app")
      }
      .help("Open in its default app (⌘O)")
      .disabled(model.selectedFile == nil)
      .accessibilityIdentifier("toolbar-open")

      Button {
        if let selectedFile = model.selectedFile { FileActions.revealInFinder(selectedFile.url) }
      } label: {
        Label("Reveal in Finder", systemImage: "folder")
      }
      .help("Reveal in Finder (⌥⌘R)")
      .disabled(model.selectedFile == nil)
      .accessibilityIdentifier("toolbar-reveal")

      Button {
        model.trashSelectedFile()
      } label: {
        Label("Move to Trash", systemImage: "trash")
      }
      .help("Move to Trash (⌘⌫)")
      .disabled(!model.canTrashSelectedFile)
      .accessibilityIdentifier("toolbar-trash")
    }
    ToolbarItem(placement: .primaryAction) {
      Button {
        model.isFilingPanelShown.toggle()
      } label: {
        Label("Filing Panel", systemImage: "sidebar.trailing")
      }
      .help(model.isFilingPanelShown ? "Hide Filing Panel (⌥⌘I)" : "Show Filing Panel (⌥⌘I)")
      .accessibilityIdentifier("toolbar-filing-panel")
    }
  }
}

#if DEBUG
  #Preview("First launch") {
    MainWindowView(
      model: .preview(folders: .preview(archiveRoot: nil, inboxes: []))
    )
    .frame(width: 1280, height: 800)
  }

  #Preview("Inboxes, nothing selected") {
    MainWindowView(
      model: .preview(
        folders: .preview(archiveRoot: SampleFolders.archiveRoot, inboxes: SampleFolders.inboxes),
        inboxes: SampleInboxes.library())
    )
    .frame(width: 1280, height: 800)
  }

  #Preview("PDF selected") {
    MainWindowView(
      model: .preview(
        folders: .preview(archiveRoot: SampleFolders.archiveRoot, inboxes: SampleFolders.inboxes),
        inboxes: SampleInboxes.library(),
        selectedFile: SampleInboxes.selectedInvoice())
    )
    .frame(width: 1280, height: 800)
  }

  #Preview("Archive unreachable") {
    MainWindowView(
      model: .preview(
        folders: .preview(
          archiveRoot: SampleFolders.missingArchiveRoot, inboxes: SampleFolders.inboxes),
        selectedFile: SampleInboxes.selectedInvoice())
    )
    .frame(width: 1280, height: 800)
  }
#endif
