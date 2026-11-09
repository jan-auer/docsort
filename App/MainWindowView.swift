import DocsortCore
import SwiftUI

/// The content of the main window: the inbox sidebar, the preview and the filing panel as a trailing pane beside it
/// (340 pt to start, dragged between 300 and 480 pt),
/// with the selected file's name as the window title, its inbox as the subtitle, and its actions in the toolbar.
///
/// The detail column shows the welcome view until folders are configured, then the selected file's preview, or a
/// quiet "No file selected" while nothing is selected, with the bottom bar (confirmations, history save warning)
/// under it. Name conflicts and failed actions are shown as alerts. Below `MainWindowModel.sidebarCollapseWidth` the sidebar
/// collapses first, so the preview keeps its room.
struct MainWindowView: View {
  /// The window's state.
  @Bindable var model: MainWindowModel

  @Environment(\.undoManager) private var undoManager

  /// The window's Quick Look panel, shared by the sidebar and Folder contents.
  @State private var quickLookPanel = QuickLookPanelController(panel: SystemQuickLookPanel())

  /// The filing panel's width, kept with the window.
  @SceneStorage("filing-panel.width") private var filingPanelWidth = 340.0

  /// The widths the filing panel can be dragged to.
  private static let filingPanelWidths = 300.0...480.0

  var body: some View {
    NavigationSplitView(columnVisibility: $model.columnVisibility) {
      SidebarColumn {
        if model.areFoldersConfigured {
          InboxSidebar(model: model)
        }
      }
      .navigationSplitViewColumnWidth(min: 200, ideal: 260, max: 400)
    } detail: {
      // The filing panel is the main work surface, not details about the selection, so it is a pane of the detail
      // column (HIG: inspectors are for details), resizable against the preview by dragging the divider between them.
      HStack(spacing: 0) {
        VStack(spacing: 0) {
          detailColumn
            .frame(maxHeight: .infinity)
          WindowBottomBar(model: model)
        }
        .frame(minWidth: 420, maxWidth: .infinity, maxHeight: .infinity)
        if model.isFilingPanelShown {
          HStack(spacing: 0) {
            PaneDivider(width: $filingPanelWidth, range: Self.filingPanelWidths)
            FilingPanel(
              model: model,
              locateArchive: { FolderChooser(folders: model.folders).chooseArchiveRoot() }
            )
            .frame(width: filingPanelWidth.clamped(to: Self.filingPanelWidths))
            .frame(maxHeight: .infinity)
          }
          // Slides in and out at the trailing edge as the inspector did, whichever command toggles it (toolbar,
          // View menu, ⌥⌘I, or focusing the filter or name field while it is hidden).
          .transition(.move(edge: .trailing))
        }
      }
      .animation(.smooth(duration: 0.3), value: model.isFilingPanelShown)
      .toolbar { fileToolbar }
      .navigationTitle(windowTitle)
      .navigationSubtitle(windowSubtitle)
    }
    .frame(minWidth: 1000, minHeight: 640)
    .background(QuickLookPanelHost(controller: quickLookPanel))
    .environment(\.quickLookPanel, quickLookPanel)
    .onGeometryChange(for: MainWindowWidthClass.self) { geometry in
      geometry.size.width < MainWindowModel.sidebarCollapseWidth ? .narrow : .regular
    } action: { widthClass in
      model.windowWidthClassChanged(to: widthClass)
    }
    .onAppear { model.undoManager = undoManager }
    .task { await model.selectFirstFileAfterInitialScan() }
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
    // The system's line between the toolbar and the content scrolling under it, as Finder shows it.
    .background(TitlebarSeparatorLine())
    .focusedSceneValue(\.mainWindowModel, model)
    .keyboardShortcutsSheet()
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

  /// The window title: the selected file's name, or the app name while nothing is selected.
  private var windowTitle: String {
    model.selectedFile?.name ?? "docsort"
  }

  /// The window subtitle: the inbox the selected file is listed under.
  private var windowSubtitle: String {
    model.selectedFile?.inboxName ?? ""
  }

  /// Previous File and Next File as one back/forward pair at the leading edge, before the system window title (like
  /// Finder's), the file's actions as one group at the right, and the filing panel toggle on its own at the far right.
  @ToolbarContentBuilder private var fileToolbar: some ToolbarContent {
    ToolbarItemGroup(placement: .navigation) {
      Button {
        model.selectFile(.previous)
      } label: {
        Label("Previous File", systemImage: "chevron.left")
      }
      .help("Previous File (⌥⌘↑)")
      .disabled(model.file(.previous) == nil)
      .accessibilityIdentifier("toolbar-previous-file")

      Button {
        model.selectFile(.next)
      } label: {
        Label("Next File", systemImage: "chevron.right")
      }
      .help("Next File (⌥⌘↓)")
      .disabled(model.file(.next) == nil)
      .accessibilityIdentifier("toolbar-next-file")
    }

    ToolbarSpacer(.flexible)

    ToolbarItemGroup {
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

    ToolbarSpacer(.fixed)

    ToolbarItem {
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
