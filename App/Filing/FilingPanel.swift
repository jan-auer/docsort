import DocsortCore
import SwiftUI

/// The filing panel, the main window's inspector: where the selected file gets its destination and name.
///
/// It is inactive until a file is selected. For an unhandled, complete file it is laid out list first, like the save
/// panel: the search field at the top, the folder list on the inspector's glass with New Folder under it, Folder contents as a
/// drawer the user resizes by dragging its header, and a bottom bar with the name field (extension and Revert inside
/// it) and the Move button (⌘Return, also File › Move). The destination line, the full path shown once, sits under the
/// search field. The file's name is in the window's title, not repeated here.
///
/// A filed file opens with a status banner ("Filed to … · today 09:41", **Move Back**) above the same parts, with
/// its current folder chosen and its current name in the name field; the button reads **Rename** or **Move** by what
/// changed and is disabled while nothing did. A trashed file shows the banner ("Moved to Trash", **Put Back**) above
/// the parts shown inactive. Failure banners sit at the top: the archive folder is unreachable (with **Locate…**), or
/// the filing history can't be read (with **Start New History** and **Show in Finder**).
struct FilingPanel: View {
  /// The window's state.
  @Bindable var model: MainWindowModel
  /// Lets the user find the unreachable archive folder again.
  let locateArchive: () -> Void

  /// The panel's SwiftUI-focusable views: the picker's two text fields and Folder contents' file list. (The name
  /// field and the sidebar take focus through `MainWindowModel.requestFocus`; this bridges the picker into the same
  /// scheme. Folder contents takes focus only by a click, and is not a focus stop of the window model.)
  enum PanelField: Hashable {
    case picker(PickerField)
    case folderContents
  }

  @FocusState private var focusedField: PanelField?

  /// The height of Folder contents' list, kept with the window.
  @SceneStorage("filing-panel.contents-height") private var contentsHeight = 150.0
  /// Whether Folder contents is collapsed to its header, kept with the window.
  @SceneStorage("filing-panel.contents-collapsed") private var isContentsCollapsed = false
  /// The height the folder list and Folder contents share.
  @State private var listsHeight = 0.0

  /// The least height the search field and the folder list keep when Folder contents grows.
  private static let pickerMinHeight = 200.0

  var body: some View {
    VStack(spacing: 0) {
      if case .unreachable(let displayPath) = model.archiveAvailability {
        archiveUnreachableNotice(displayPath: displayPath)
      }
      if case .unreadable(let error) = model.filing.historyAvailability {
        historyUnreadableNotice(reason: error.description)
      }
      if let selectedFile = model.selectedFile {
        selectedFileSections(for: selectedFile)
      } else {
        inactiveMessage
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    // No background of its own: the panel is the window's inspector, and the system's edge-to-edge glass behind it
    // runs from the window's top edge to its bottom, toolbar section included, with no seam between them.
    .accessibilityElement(children: .contain)
    .accessibilityIdentifier("filing-panel")
  }

  /// The panel's content for a selected file.
  @ViewBuilder private func selectedFileSections(for file: SelectedFile) -> some View {
    if let status = stripStatus(for: file) {
      FilingStatusStrip(
        status: status, inboxName: file.inboxName,
        canReturnToInbox: model.canReturnSelectedFileToInbox,
        returnToInbox: { model.returnSelectedFileToInbox() })
      Divider()
    }

    if file.mark == nil, file.completeness == .downloading {
      ContentUnavailableView(
        "Still Downloading", systemImage: "icloud.and.arrow.down",
        description: Text("This file can be filed once its download has finished."))
    } else {
      // One branch for unhandled, filed and trashed files, so the picker keeps its identity (and focus handling)
      // when the selected file's state changes; a trashed file's sections are shown inactive.
      filingSections(for: file)
        .disabled(file.isTrashed)
    }
  }

  /// What the status strip shows for `file`; `nil` while it is unhandled.
  private func stripStatus(for file: SelectedFile) -> FilingStatusStrip.Status? {
    switch file.mark {
    case .filed(_, let destinationPath, let date, _):
      .filed(destinationPath: destinationPath, date: date)
    case .trashed(_, let date): .trashed(date: date)
    case nil: nil
    }
  }

  private func filingSections(for file: SelectedFile) -> some View {
    VStack(spacing: 0) {
      VStack(spacing: 0) {
        picker
          .frame(maxHeight: .infinity)
        FolderContentsView(
          model: model.picker, conflictingName: model.nameToCheckForConflicts,
          canChangeFiles: model.canChangeArchiveFiles, focus: $focusedField,
          field: .folderContents, listHeight: $contentsHeight, isCollapsed: $isContentsCollapsed,
          maxListHeight: max(
            listsHeight - Self.pickerMinHeight, FilingPanelStyle.contentsMinListHeight))
      }
      .onGeometryChange(for: Double.self) { geometry in
        geometry.size.height
      } action: { height in
        listsHeight = height
      }
      FilingPanelStyle.insetDivider
      bottomBar(for: file)
    }
  }

  private var picker: some View {
    DestinationPickerView(model: model.picker, focus: $focusedField, field: { .picker($0) })
      .task(id: model.focusRequest) {
        // A request for the filter (typing in the sidebar, ⇧Tab or Esc in the name field) focuses it here, also
        // when the picker only just appeared for a newly selected file. If the focus value still says "filter"
        // although focus went elsewhere outside SwiftUI, assigning it again would change nothing; clear it first.
        guard model.focusRequest?.target == .destinationFilter else { return }
        if focusedField != nil {
          focusedField = nil
          await Task.yield()
        }
        focusedField = .picker(.filter)
      }
      .onChange(of: focusedField, initial: true) { _, field in
        if case .picker = field {
          model.focus = .destinationFilter
          model.panel.isFilterFocusPending = false
        } else if model.focus == .destinationFilter {
          model.focus = nil
        }
      }
  }

  /// The bottom bar: "Name" with the name field, a notice if moving failed, and the Move button at the trailing end.
  /// The destination is named under the search field, where it is chosen.
  private func bottomBar(for file: SelectedFile) -> some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack(spacing: 8) {
        Text("Name:")
          .foregroundStyle(.secondary)
        NameField(model: model, file: file)
      }
      // The Return toast floats below the field, over the notice and the Move button.
      .zIndex(1)

      if let notice = model.panel.notice {
        Label(notice, systemImage: "exclamationmark.octagon.fill")
          .foregroundStyle(.red)
          .fixedSize(horizontal: false, vertical: true)
          .accessibilityIdentifier("filing-panel-notice")
      }

      HStack {
        Spacer()
        moveButton
      }
    }
    .padding(.horizontal, FilingPanelStyle.edgeMargin)
    .padding(.top, 12)
    .padding(.bottom, 14)
  }

  /// Move (or Rename), prominent and large, with its shortcut as a key-cap badge inside, as the user chose.
  private var moveButton: some View {
    Button {
      model.moveSelectedFile()
    } label: {
      HStack(spacing: 8) {
        Text(moveButtonTitle)
        Text(MenuCommand.move.keys.notation)
          .font(.callout)
          .padding(.horizontal, 6)
          .padding(.vertical, 1)
          .background(.white.opacity(0.22), in: Capsule())
          .fixedSize()
          .accessibilityHidden(true)
      }
      .padding(.horizontal, 4)
    }
    .buttonStyle(.borderedProminent)
    .buttonBorderShape(.capsule)
    .controlSize(.large)
    .disabled(!model.canMoveSelectedFile)
    .help("\(moveButtonTitle) (\(MenuCommand.move.keys.notation))")
    .accessibilityLabel(moveButtonTitle)
    .accessibilityIdentifier("move-button")
  }

  /// The bottom button's title: **Rename** when only a filed file's name changed, **Move** otherwise.
  private var moveButtonTitle: String {
    model.filedFileChange == .rename ? "Rename" : "Move"
  }

  private var inactiveMessage: some View {
    ContentUnavailableView(
      "Nothing to File", systemImage: "tray",
      description: Text("Select a file in the sidebar to choose its folder and name.")
    )
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .accessibilityIdentifier("filing-panel-inactive")
  }

  private func archiveUnreachableNotice(displayPath: String) -> some View {
    FailureNotice(
      message: "Archive folder not available: \(displayPath)",
      identifier: "filing-panel-archive-unreachable"
    ) {
      Button("Locate…", action: locateArchive)
        .accessibilityIdentifier("filing-panel-locate-archive")
    }
  }

  private func historyUnreadableNotice(reason: String) -> some View {
    FailureNotice(
      message: "The filing history can’t be read: \(reason)",
      identifier: "filing-panel-history-unreadable"
    ) {
      HStack {
        Button("Start New History") { model.startNewHistory() }
          .accessibilityIdentifier("filing-panel-start-new-history")
        Button("Show in Finder") { FileActions.revealInFinder(model.filing.historyFileURL) }
          .accessibilityIdentifier("filing-panel-show-history-file")
      }
    }
  }
}

/// A failure banner across the top of the panel (archive unreachable, history unreadable): an orange warning symbol
/// on an orange tint, so it never reads like the neutral filed/trashed status banner.
private struct FailureNotice<Actions: View>: View {
  let message: String
  let identifier: String
  @ViewBuilder let actions: () -> Actions

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      Label {
        Text(message)
          .fixedSize(horizontal: false, vertical: true)
      } icon: {
        Image(systemName: "exclamationmark.triangle.fill")
          .foregroundStyle(.orange)
      }
      actions()
        .controlSize(.small)
    }
    .padding(.horizontal, FilingPanelStyle.edgeMargin)
    .padding(.vertical, 10)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(Color.orange.opacity(0.14), ignoresSafeAreaEdges: [])
    .overlay(alignment: .bottom) { Divider() }
    .accessibilityElement(children: .contain)
    .accessibilityIdentifier(identifier)
  }
}

#if DEBUG
  #Preview("Nothing selected") {
    FilingPanel(
      model: .preview(
        folders: .preview(archiveRoot: SampleFolders.archiveRoot, inboxes: SampleFolders.inboxes)),
      locateArchive: {}
    )
    .frame(width: 340, height: 600)
  }

  #Preview("File selected") {
    FilingPanel(
      model: .preview(
        folders: .preview(archiveRoot: SampleFolders.archiveRoot, inboxes: SampleFolders.inboxes),
        selectedFile: SampleInboxes.selectedInvoice()),
      locateArchive: {}
    )
    .frame(width: 340, height: 600)
  }

  #Preview("Edited name, Return toast") {
    let model = MainWindowModel.preview(
      folders: .preview(archiveRoot: SampleFolders.archiveRoot, inboxes: SampleFolders.inboxes),
      selectedFile: SampleInboxes.selectedInvoice())
    model.panel.nameText = "2033-10-13 Notenhaus Allegretto"
    model.panel.hint = .pressCommandReturnToMove
    return FilingPanel(model: model, locateArchive: {})
      .frame(width: 340, height: 600)
  }

  #Preview("Filed file") {
    FilingPanel(
      model: .preview(
        folders: .preview(archiveRoot: SampleFolders.archiveRoot, inboxes: SampleFolders.inboxes),
        selectedFile: SampleInboxes.filedInvoice()),
      locateArchive: {}
    )
    .frame(width: 340, height: 600)
  }

  #Preview("Trashed file") {
    FilingPanel(
      model: .preview(
        folders: .preview(archiveRoot: SampleFolders.archiveRoot, inboxes: SampleFolders.inboxes),
        selectedFile: SampleInboxes.trashedInvoice()),
      locateArchive: {}
    )
    .frame(width: 340, height: 600)
  }

  #Preview("Archive unreachable") {
    FilingPanel(
      model: .preview(
        folders: .preview(
          archiveRoot: SampleFolders.missingArchiveRoot, inboxes: SampleFolders.inboxes),
        selectedFile: SampleInboxes.selectedInvoice()),
      locateArchive: {}
    )
    .frame(width: 340, height: 600)
  }
#endif
