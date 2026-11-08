import DocsortCore
import SwiftUI

/// The filing panel, the main window's inspector: where the selected file gets its destination and name.
///
/// It is inactive until a file is selected. For an unhandled, complete file it shows, top to bottom: the file's name,
/// the destination picker (filter, path bar, folder list, New Folder), the chosen or highlighted folder's contents,
/// the name field with the extension as a fixed label, and the Move button (⌘Return, also File › Move). A filed or
/// trashed file shows what happened to it instead. Notices sit at the top: the archive folder is unreachable (with **Locate…**), or the filing history
/// can't be read (with **Start New History** and **Show in Finder**).
struct FilingPanel: View {
  /// The window's state.
  @Bindable var model: MainWindowModel
  /// Lets the user find the unreachable archive folder again.
  let locateArchive: () -> Void

  /// The panel's SwiftUI-focusable fields: the picker's two text fields. (The name field and the sidebar take focus
  /// through `MainWindowModel.requestFocus`; this bridges the picker into the same scheme.)
  enum PanelField: Hashable {
    case picker(PickerField)
  }

  @FocusState private var focusedField: PanelField?

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
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
    .padding(16)
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    .accessibilityElement(children: .contain)
    .accessibilityIdentifier("filing-panel")
  }

  /// The panel's content for a selected file.
  @ViewBuilder private func selectedFileSections(for file: SelectedFile) -> some View {
    Text(file.originalName)
      .font(.headline)
      .lineLimit(2)
      .truncationMode(.middle)
      .textSelection(.enabled)
      .accessibilityIdentifier("filing-panel-file-name")

    switch file.mark {
    case .filed(_, let destinationPath):
      handledStrip(
        systemImage: "checkmark.circle.fill", color: .green,
        text: "Filed to \(destinationPath) as \(file.name)")
    case .trashed:
      handledStrip(systemImage: "trash", color: .secondary, text: "Moved to Trash")
    case nil:
      if file.completeness == .downloading {
        Label("This file is still downloading.", systemImage: "icloud.and.arrow.down")
          .foregroundStyle(.secondary)
      } else {
        filingSections(for: file)
      }
    }
  }

  @ViewBuilder private func filingSections(for file: SelectedFile) -> some View {
    Text("Destination")
      .font(.subheadline.weight(.semibold))
      .foregroundStyle(.secondary)
    DestinationPickerView(model: model.picker, focus: $focusedField, field: { .picker($0) })
      .frame(minHeight: 180, maxHeight: .infinity)
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
        if field != nil {
          model.focus = .destinationFilter
          model.panel.isFilterFocusPending = false
        } else if model.focus == .destinationFilter {
          model.focus = nil
        }
      }
      .onChange(of: model.focus) { _, focus in
        // The name field and the sidebar take focus outside this focus state (AppKit's `makeFirstResponder`, the
        // sidebar's own focus state); keep it in step, so the picker stops treating its fields as focused.
        if focus == .nameField || focus == .sidebar, focusedField != nil { focusedField = nil }
      }
    FolderContentsView(model: model.picker, conflictingName: model.finalName)
      .frame(minHeight: 80, maxHeight: 200)

    Text("Name")
      .font(.subheadline.weight(.semibold))
      .foregroundStyle(.secondary)
    NameField(model: model, file: file)

    if let notice = model.panel.notice {
      Label(notice, systemImage: "exclamationmark.octagon.fill")
        .foregroundStyle(.red)
        .fixedSize(horizontal: false, vertical: true)
        .accessibilityIdentifier("filing-panel-notice")
    }

    HStack {
      Spacer()
      Button {
        model.moveSelectedFile()
      } label: {
        HStack(spacing: 6) {
          Text("Move")
          Text("⌘↩")
            .font(.caption)
            .padding(.horizontal, 4)
            .background(.white.opacity(0.2), in: RoundedRectangle(cornerRadius: 4))
            .accessibilityHidden(true)
        }
      }
      .buttonStyle(.borderedProminent)
      .controlSize(.large)
      .disabled(!model.canMoveSelectedFile)
      .help("Move (⌘Return)")
      .accessibilityIdentifier("move-button")
    }
  }

  private func handledStrip(systemImage: String, color: Color, text: String) -> some View {
    Label {
      Text(text)
        .lineLimit(3)
    } icon: {
      Image(systemName: systemImage)
        .foregroundStyle(color)
    }
    .padding(8)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(.quaternary, in: RoundedRectangle(cornerRadius: 6))
    .accessibilityElement(children: .combine)
    .accessibilityIdentifier("filing-panel-handled")
  }

  private var inactiveMessage: some View {
    Text("Select a file to file it")
      .foregroundStyle(.tertiary)
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .accessibilityIdentifier("filing-panel-inactive")
  }

  private func archiveUnreachableNotice(displayPath: String) -> some View {
    VStack(alignment: .leading, spacing: 8) {
      Label(
        "Archive folder not available: \(displayPath)",
        systemImage: "exclamationmark.triangle.fill"
      )
      .symbolRenderingMode(.multicolor)
      Button("Locate…", action: locateArchive)
        .accessibilityIdentifier("filing-panel-locate-archive")
    }
    .padding(10)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
    .accessibilityElement(children: .contain)
    .accessibilityIdentifier("filing-panel-archive-unreachable")
  }

  private func historyUnreadableNotice(reason: String) -> some View {
    VStack(alignment: .leading, spacing: 8) {
      Label(
        "The filing history can’t be read: \(reason)",
        systemImage: "exclamationmark.triangle.fill"
      )
      .symbolRenderingMode(.multicolor)
      .fixedSize(horizontal: false, vertical: true)
      HStack {
        Button("Start New History") { model.startNewHistory() }
          .accessibilityIdentifier("filing-panel-start-new-history")
        Button("Show in Finder") { FileActions.revealInFinder(model.filing.historyFileURL) }
          .accessibilityIdentifier("filing-panel-show-history-file")
      }
    }
    .padding(10)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
    .accessibilityElement(children: .contain)
    .accessibilityIdentifier("filing-panel-history-unreadable")
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
