import DocsortCore
import SwiftUI

/// The content of the main window: the inbox sidebar, the preview and the filing panel as the window's inspector,
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

  /// The filing panel's width as the user last left it, kept with the window.
  @SceneStorage("filing-panel.width") private var filingPanelWidth = 340.0
  /// The width the inspector opens at in this window: the stored width, read once, because the inspector takes its
  /// ideal width only when it first lays out and a changing ideal would fight the user's drag.
  @State private var initialFilingPanelWidth: Double?

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
      // Declared on the detail column, so these items sit over the preview: the file actions at the trailing end of
      // the content's part of the toolbar, left of the inspector's.
      .toolbar {
        fileNavigationToolbar
        ToolbarSpacer(.flexible)
        fileActionsToolbar
      }
      .navigationTitle(windowTitle)
      .navigationSubtitle(windowSubtitle)
    }
    // The minimum size goes on the split view, inside the inspector: the inspector's width adds to it, so the window
    // keeps its 1000 pt minimum at the panel's default 340 pt. Outside `.inspector`, a minimum width held the content
    // at the window's width while the inspector slid in: the whole window content grew wider than the window and
    // shifted left until the animation ended, pushing toolbar items into the overflow menu.
    .frame(minWidth: 1000 - 340, minHeight: 640)
    // Spike (`inspector-glass`): the filing panel as the window's inspector, attached to the split view itself, so
    // the system draws it full height as edge-to-edge glass beside the content (WWDC25 310 and 323). The system
    // slides it in and out; its user-dragged width is kept in `filingPanelWidth` and used as the next window's ideal.
    .inspector(isPresented: $model.isFilingPanelShown) {
      FilingPanel(
        model: model,
        locateArchive: { FolderChooser(folders: model.folders).chooseArchiveRoot() }
      )
      .onAppear {
        if initialFilingPanelWidth == nil { initialFilingPanelWidth = filingPanelWidth }
      }
      .onGeometryChange(for: Double.self) { geometry in
        geometry.size.width
      } action: { width in
        if Self.filingPanelWidths.contains(width) { filingPanelWidth = width }
      }
      .inspectorColumnWidth(
        min: Self.filingPanelWidths.lowerBound,
        ideal: initialFilingPanelWidth ?? filingPanelWidth,
        max: Self.filingPanelWidths.upperBound
      )
    }
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
    // The system's line between the toolbar and the content scrolling under it, as Finder shows it, and none over the
    // inspector's glass.
    .background(TitlebarSeparatorLine())
    .background(AttachedSheetObserver(model: model))
    #if DEBUG
      .background(WindowLayoutProbe())
    #endif
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

  /// The widths the filing panel can be dragged to.
  private static let filingPanelWidths = 300.0...480.0

  /// Previous File and Next File as one back/forward pair at the leading edge, before the system window title (like
  /// Finder's).
  @ToolbarContentBuilder private var fileNavigationToolbar: some ToolbarContent {
    ToolbarItemGroup(placement: .navigation) {
      Button {
        model.selectFile(.previous)
      } label: {
        Label("Previous File", systemImage: "chevron.left")
      }
      .help("Previous File (\(MenuCommand.previousFile.keys.notation))")
      .disabled(model.file(.previous) == nil)
      .accessibilityIdentifier("toolbar-previous-file")

      Button {
        model.selectFile(.next)
      } label: {
        Label("Next File", systemImage: "chevron.right")
      }
      .help("Next File (\(MenuCommand.nextFile.keys.notation))")
      .disabled(model.file(.next) == nil)
      .accessibilityIdentifier("toolbar-next-file")
    }
  }

  /// The selected file's actions as one group. Its own piece, so it can move over the filing panel (into the
  /// inspector's `.toolbar`) if the toolbar study decides so.
  @ToolbarContentBuilder private var fileActionsToolbar: some ToolbarContent {
    ToolbarItemGroup {
      Button {
        if let selectedFile = model.selectedFile { FileActions.open(selectedFile.url) }
      } label: {
        Label("Open", systemImage: "arrow.up.forward.app")
      }
      .help("Open in its default app (\(MenuCommand.open.keys.notation))")
      .disabled(model.selectedFile == nil)
      .accessibilityIdentifier("toolbar-open")

      Button {
        if let selectedFile = model.selectedFile { FileActions.revealInFinder(selectedFile.url) }
      } label: {
        Label("Reveal in Finder", systemImage: "folder")
      }
      .help("Reveal in Finder (\(MenuCommand.revealInFinder.keys.notation))")
      .disabled(model.selectedFile == nil)
      .accessibilityIdentifier("toolbar-reveal")

      Button {
        model.trashSelectedFile()
      } label: {
        Label("Move to Trash", systemImage: "trash")
      }
      .help("Move to Trash (\(MenuCommand.moveToTrash.keys.notation))")
      .disabled(!model.canTrashSelectedFile)
      .accessibilityIdentifier("toolbar-trash")
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
