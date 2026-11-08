import SwiftUI

/// The content of the main window: the inbox sidebar, the preview and the filing panel as an inspector, with the
/// selected file's name and actions in the toolbar.
///
/// The detail column shows the welcome view until folders are configured, then the selected file's preview, or a
/// quiet "No file selected" while nothing is selected. Below `MainWindowModel.sidebarCollapseWidth` the sidebar
/// collapses first, so the preview keeps its room.
struct MainWindowView: View {
  /// The window's state.
  @Bindable var model: MainWindowModel

  @Environment(\.openSettings) private var openSettings

  var body: some View {
    NavigationSplitView(columnVisibility: $model.columnVisibility) {
      SidebarColumn {}
        .navigationSplitViewColumnWidth(min: 200, ideal: 260, max: 400)
    } detail: {
      detailColumn
        .frame(minWidth: 420, maxWidth: .infinity, maxHeight: .infinity)
        .toolbar { fileToolbar }
    }
    .inspector(isPresented: $model.isFilingPanelShown) {
      FilingPanel(
        selectedFile: model.selectedFile,
        archiveAvailability: model.archiveAvailability,
        // Settings is where the archive folder is chosen; the Settings step may offer a folder picker here instead.
        locateArchive: { openSettings() }
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
    .focusedSceneValue(\.mainWindowModel, model)
    .accessibilityElement(children: .contain)
    .accessibilityIdentifier("main-window")
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

  /// The selected file's inbox and name, its actions, and the filing panel toggle.
  @ToolbarContentBuilder private var fileToolbar: some ToolbarContent {
    ToolbarItem(placement: .navigation) {
      if let selectedFile = model.selectedFile {
        Text("\(selectedFile.inboxName) › \(selectedFile.name)")
          .lineLimit(1)
          .truncationMode(.middle)
          .frame(minWidth: 120, maxWidth: 480, alignment: .leading)
          .help("\(selectedFile.inboxName) › \(selectedFile.name)")
          .accessibilityIdentifier("toolbar-file-title")
      }
    }
    // Move to Trash joins this group after Reveal in Finder once trashing is built.
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

#Preview("First launch") {
  MainWindowView(model: MainWindowModel(areFoldersConfigured: false))
    .frame(width: 1280, height: 800)
}

#Preview("Nothing selected") {
  MainWindowView(model: MainWindowModel(areFoldersConfigured: true))
    .frame(width: 1280, height: 800)
}

#if DEBUG
  #Preview("PDF selected") {
    MainWindowView(
      model: MainWindowModel(
        areFoldersConfigured: true,
        selectedFile: SelectedFile(
          url: PreviewSampleFiles.invoicePDF(),
          inboxName: "Web-Downloads",
          completeness: .complete
        )
      )
    )
    .frame(width: 1280, height: 800)
  }

  #Preview("Archive unreachable") {
    let model = MainWindowModel(
      areFoldersConfigured: true,
      selectedFile: SelectedFile(
        url: PreviewSampleFiles.textNote(),
        inboxName: "Scanner",
        completeness: .complete
      )
    )
    model.archiveAvailability = .unreachable(displayPath: "~/Archiv")
    return MainWindowView(model: model)
      .frame(width: 1280, height: 800)
  }
#endif
