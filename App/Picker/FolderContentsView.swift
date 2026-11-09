import AppKit
import DocsortCore
import SwiftUI
import UniformTypeIdentifiers

/// Folder contents (`docs/design/ux.md`, "Folder contents"): the files already in the chosen or highlighted folder,
/// alphabetically, scrolled to the bottom (the newest of the archive's date-named files) whenever the folder changes.
///
/// Files are selected as in Finder: a click selects a file and focuses the list, ↑ ↓ move the selection, Space opens
/// the Quick Look panel on it (↑ ↓ then move through the files with the panel following; Space or Esc closes it),
/// and a double-click or Return uses its name for the name field (``PickerEvent/tookFileName(_:)``). A file's context
/// menu offers Use Name, Quick Look, Open, Open With, Reveal in Finder, Copy Name, Copy Path, Rename… and Move to
/// Trash (``FolderContentsFileMenu``).
///
/// It is a drawer under the folder list: its header ("Files in Rechnungen", the file count) can be dragged up and down
/// to resize the list under it, and its chevron collapses the drawer to the header.
///
/// Accessibility: the view is `folder-contents`; the header is `folder-contents-header`, its chevron
/// `folder-contents-toggle`; the file list is `folder-contents-list`; each file is a button `folder-contents-file`
/// labelled with its name, with the value `selected` when it is selected, `conflict` when it is the conflicting file
/// (`selected, conflict` when both).
struct FolderContentsView<FocusValue: Hashable>: View {
  let model: DestinationPickerModel
  /// The name the name field would give the file; a file with this name (ignoring case) is highlighted in the
  /// warning colour and scrolled into view.
  var conflictingName: String? = nil
  /// Whether Rename… and Move to Trash are available (the history is writable and nothing is being filed).
  var canChangeFiles = true
  /// The panel's focus, and the value that stands for the file list.
  let focus: FocusState<FocusValue?>.Binding
  let field: FocusValue
  /// The height of the file list under the header.
  @Binding var listHeight: Double
  /// Whether the drawer shows only its header.
  @Binding var isCollapsed: Bool
  /// The tallest the list may get, so the folder list above keeps its room.
  let maxListHeight: Double

  @Environment(\.quickLookPanel) private var quickLookPanel

  var body: some View {
    FolderContentsListing(
      contents: model.contents, selectedURL: model.selectedContentsFile?.url,
      conflictingName: conflictingName, isListFocused: focus.wrappedValue == field,
      listHeight: $listHeight, isCollapsed: $isCollapsed, maxListHeight: maxListHeight,
      actions: actions
    )
    .focused(focus, equals: field)
  }

  /// What the listing's clicks, keys and menu items do.
  private var actions: FolderContentsActions {
    FolderContentsActions(
      canChangeFiles: canChangeFiles,
      select: { file in
        model.selectContentsFile(file)
        focus.wrappedValue = field
      },
      useName: { file in model.takeFileName(file) },
      useSelectedName: { model.useSelectedContentsFileName() },
      moveSelection: { offset in model.moveContentsSelection(by: offset) },
      toggleQuickLook: { quickLookPanel?.toggle(for: model) },
      quickLook: { file in
        model.selectContentsFile(file)
        quickLookPanel?.show(for: model)
      },
      rename: { file, name in model.requestRename(of: file, to: name) },
      trash: { file in model.requestTrash(of: file) })
  }
}

/// What Folder contents' clicks, keys and menu items do; ``FolderContentsView`` wires them to the picker model.
struct FolderContentsActions {
  /// Whether Rename… and Move to Trash are enabled.
  var canChangeFiles = true
  /// A click: select the file (and focus the list).
  var select: (FolderFile) -> Void = { _ in }
  /// A double-click or Use Name: use the file's name.
  var useName: (FolderFile) -> Void = { _ in }
  /// Return: use the selected file's name.
  var useSelectedName: () -> Void = {}
  /// ↑ (`-1`) or ↓ (`1`).
  var moveSelection: (Int) -> Void = { _ in }
  /// Space: open or close the Quick Look panel on the selection.
  var toggleQuickLook: () -> Void = {}
  /// Quick Look in the file's menu: select it and show it in the panel.
  var quickLook: (FolderFile) -> Void = { _ in }
  /// Rename… confirmed with the name entered (without the extension).
  var rename: (FolderFile, String) -> Void = { _, _ in }
  /// Move to Trash.
  var trash: (FolderFile) -> Void = { _ in }
}

/// Folder contents for one ``FolderContents`` value; ``FolderContentsView`` feeds it from the picker model.
struct FolderContentsListing: View {
  let contents: FolderContents
  /// The selected file, if any.
  var selectedURL: URL? = nil
  let conflictingName: String?
  /// Whether the file list has keyboard focus: the selection shows in the accent colour then, grey otherwise.
  var isListFocused = false
  @Binding var listHeight: Double
  @Binding var isCollapsed: Bool
  let maxListHeight: Double
  var actions = FolderContentsActions()

  /// The list height when a drag started.
  @State private var dragStartHeight: Double?
  /// The file Rename… is asking a new name for.
  @State private var fileToRename: FolderFile?
  /// The name typed in the Rename dialog, without the extension.
  @State private var newName = ""

  /// The shortest the list gets while expanded.
  static let minListHeight: Double = 48

  var body: some View {
    VStack(spacing: 0) {
      header
      if !isCollapsed {
        Divider()
        content
          .frame(maxWidth: .infinity, alignment: .topLeading)
          .frame(height: clampedListHeight, alignment: .topLeading)
          .background(FilingPanelStyle.listBackground)
      }
    }
    .accessibilityElement(children: .contain)
    .accessibilityLabel("Folder contents")
    .accessibilityIdentifier("folder-contents")
  }

  private var clampedListHeight: Double {
    min(max(listHeight, Self.minListHeight), max(maxListHeight, Self.minListHeight))
  }

  // MARK: Header

  /// The drawer's header: a chevron that collapses it, "Files in Rechnungen" with the file count trailing (the
  /// folder's full path is in its tooltip), and a grab bar, which alone shows the resize cursor; dragging anywhere on
  /// the header resizes the list.
  private var header: some View {
    HStack(alignment: .firstTextBaseline, spacing: 6) {
      Button {
        isCollapsed.toggle()
      } label: {
        Image(systemName: "chevron.right")
          .font(.footnote.weight(.semibold))
          .rotationEffect(.degrees(isCollapsed ? 0 : 90))
          .foregroundStyle(.secondary)
          .frame(width: 14, height: 14)
          .contentShape(Rectangle())
      }
      .buttonStyle(.plain)
      .help(isCollapsed ? "Show the folder’s files" : "Hide the folder’s files")
      .accessibilityLabel(isCollapsed ? "Show files" : "Hide files")
      .accessibilityIdentifier("folder-contents-toggle")
      Text(headerTitle)
        .font(.subheadline.weight(.semibold))
        .foregroundStyle(.secondary)
        .lineLimit(1)
        .truncationMode(.middle)
        .help(contents.folder.map(Self.title(of:)) ?? "")
        .accessibilityAddTraits(.isHeader)
        .accessibilityIdentifier("folder-contents-header")
      Spacer(minLength: 4)
      if let fileCount {
        Text(fileCount == 1 ? "1 file" : "\(fileCount) files")
          .font(.subheadline)
          .foregroundStyle(.secondary)
          .fixedSize()
      }
    }
    .padding(.horizontal, FilingPanelStyle.edgeMargin)
    .padding(.top, 9)
    .padding(.bottom, 6)
    .overlay(alignment: .top) {
      // The grab bar: the only part that shows the resize cursor, with a hit area larger than the bar itself.
      Capsule()
        .fill(.quaternary)
        .frame(width: 32, height: 3)
        .frame(width: 64, height: 9)
        .contentShape(Rectangle())
        .pointerStyle(.rowResize)
        .help("Drag to resize")
        .accessibilityHidden(true)
    }
    .frame(maxWidth: .infinity)
    .contentShape(Rectangle())
    .gesture(resizeGesture)
    .accessibilityAdjustableAction { direction in
      switch direction {
      case .increment: listHeight = min(clampedListHeight + 24, maxListHeight)
      case .decrement: listHeight = max(clampedListHeight - 24, Self.minListHeight)
      @unknown default: break
      }
    }
  }

  /// Dragging the header: up makes the list taller, down shorter; dragging a collapsed drawer up opens it.
  private var resizeGesture: some Gesture {
    DragGesture(minimumDistance: 2, coordinateSpace: .global)
      .onChanged { drag in
        if isCollapsed {
          guard drag.translation.height < -8 else { return }
          isCollapsed = false
          listHeight = Self.minListHeight
        }
        let start = dragStartHeight ?? clampedListHeight
        dragStartHeight = start
        listHeight = min(max(start - drag.translation.height, Self.minListHeight), maxListHeight)
      }
      .onEnded { _ in
        dragStartHeight = nil
      }
  }

  /// "Files in <folder name>", "Files in new folder", or "Folder contents" without a folder.
  private var headerTitle: String {
    switch contents {
    case .none: "Folder contents"
    case .notOnDisk: "Files in new folder"
    case .loading(let folder), .files(let folder, _), .failed(let folder, _):
      "Files in \(ArchivePath.title(of: folder))"
    }
  }

  private var fileCount: Int? {
    if case .files(_, let files) = contents { return files.count }
    return nil
  }

  /// A folder's path as the header shows it: `Gesundheit › Konrad`, or ``ArchivePath/rootTitle``.
  static func title(of folder: String) -> String {
    folder.isEmpty
      ? ArchivePath.rootTitle : ArchivePath.segments(of: folder).joined(separator: " › ")
  }

  // MARK: Content

  @ViewBuilder
  private var content: some View {
    switch contents {
    case .none:
      note("Highlight a folder to see its files.")
    case .notOnDisk:
      note(
        "docsort creates the new folder when you move the file, so cancelling leaves nothing behind."
      )
    case .loading:
      // Listing a folder takes a moment at most; an empty area avoids a spinner flashing up.
      Color.clear
    case .files(_, let files) where files.isEmpty:
      note("No files")
    case .files(_, let files):
      fileList(files)
    case .failed(_, let message):
      Label(message, systemImage: "exclamationmark.triangle.fill")
        .foregroundStyle(.secondary)
        .padding(.horizontal, FilingPanelStyle.rowPadding + FilingPanelStyle.listInset)
        .padding(.vertical, 8)
    }
  }

  private func note(_ text: String) -> some View {
    Text(text)
      .foregroundStyle(.secondary)
      .fixedSize(horizontal: false, vertical: true)
      .padding(.horizontal, FilingPanelStyle.rowPadding + FilingPanelStyle.listInset)
      .padding(.vertical, 8)
  }

  private func fileList(_ files: [FolderFile]) -> some View {
    let conflict = conflictingFile(in: files)
    return ScrollViewReader { proxy in
      ScrollView {
        LazyVStack(spacing: 0) {
          ForEach(files, id: \.url) { file in
            FolderContentsFileRow(
              file: file, highlight: highlight(of: file), isConflict: file.url == conflict?.url,
              select: { actions.select(file) }, useName: { actions.useName(file) }
            )
            .contextMenu {
              FolderContentsFileMenu(
                file: file, canChangeFiles: actions.canChangeFiles,
                useName: { actions.useName(file) }, quickLook: { actions.quickLook(file) },
                rename: { beginRename(of: file) }, trash: { actions.trash(file) })
            }
            .id(file.url)
          }
        }
        .padding(.horizontal, FilingPanelStyle.listInset)
        .padding(.vertical, 4)
      }
      .defaultScrollAnchor(.bottom)
      .focusable()
      .focusEffectDisabled()
      .onKeyPress(phases: .down, action: handle)
      .accessibilityIdentifier("folder-contents-list")
      .onChange(of: files.map(\.url), initial: true) { _, urls in
        // A new folder (or new files in it): show the conflict if there is one, else the selection or the newest.
        if let conflict {
          proxy.scrollTo(conflict.url, anchor: .center)
        } else if let selectedURL, urls.contains(selectedURL) {
          proxy.scrollTo(selectedURL)
        } else if let last = urls.last {
          proxy.scrollTo(last, anchor: .bottom)
        }
      }
      .onChange(of: conflict?.url) { _, url in
        guard let url else { return }
        proxy.scrollTo(url, anchor: .center)
      }
      .onChange(of: selectedURL) { _, url in
        guard let url else { return }
        proxy.scrollTo(url)
      }
    }
    .alert(
      renameTitle, isPresented: isRenaming, presenting: fileToRename
    ) { file in
      TextField("Name", text: $newName)
      Button("Rename") { actions.rename(file, newName) }
      Button("Cancel", role: .cancel) {}
    } message: { file in
      Text(Self.renameMessage(for: file))
    }
  }

  /// The selection's look for `file`: accent while the list has focus, grey while it does not.
  private func highlight(of file: FolderFile) -> RowHighlight {
    guard file.url == selectedURL else { return .none }
    return isListFocused ? .focused : .unfocused
  }

  /// The keys of the focused list: ↑ ↓ move the selection, Space opens or closes Quick Look, Return uses the name.
  private func handle(_ press: KeyPress) -> KeyPress.Result {
    guard press.modifiers.isDisjoint(with: [.command, .control, .option, .shift]) else {
      return .ignored
    }
    switch press.key {
    case .upArrow: actions.moveSelection(-1)
    case .downArrow: actions.moveSelection(1)
    case .space: actions.toggleQuickLook()
    case .return: actions.useSelectedName()
    default: return .ignored
    }
    return .handled
  }

  // MARK: Rename

  /// Opens the Rename dialog for `file`, with its name without extension filled in.
  private func beginRename(of file: FolderFile) {
    newName = FileNameParts(file.name).stem
    fileToRename = file
  }

  private var isRenaming: Binding<Bool> {
    Binding {
      fileToRename != nil
    } set: { isPresented in
      if !isPresented { fileToRename = nil }
    }
  }

  private var renameTitle: String {
    fileToRename.map { "Rename “\($0.name)”" } ?? "Rename"
  }

  /// The Rename dialog's message: what the extension does.
  static func renameMessage(for file: FolderFile) -> String {
    guard let fileExtension = FileNameParts(file.name).fileExtension else {
      return "Enter a new name."
    }
    return "Enter a new name. The file keeps its extension “.\(fileExtension)”."
  }

  /// The file named ``conflictingName``, ignoring case and Unicode normalisation.
  private func conflictingFile(in files: [FolderFile]) -> FolderFile? {
    guard let conflictingName else { return nil }
    let folded = conflictingName.precomposedStringWithCanonicalMapping
    return files.first { file in
      file.name.precomposedStringWithCanonicalMapping.caseInsensitiveCompare(folded) == .orderedSame
    }
  }
}

/// One file in Folder contents: its icon and name, in the same row style as the folder list. A click selects it, a
/// double-click uses its name.
struct FolderContentsFileRow: View {
  let file: FolderFile
  /// How the row shows the selection.
  let highlight: RowHighlight
  /// Whether the file's name conflicts with the name field's (highlighted in the warning colour).
  let isConflict: Bool
  let select: () -> Void
  let useName: () -> Void

  var body: some View {
    HStack(spacing: FilingPanelStyle.rowIconSpacing) {
      Image(nsImage: Self.icon(for: file.name))
        .resizable()
        .frame(width: 16, height: 16)
        .accessibilityHidden(true)
      Text(file.name)
        .fontWeight(isConflict ? .semibold : .regular)
        .foregroundStyle(highlight.textTone.primary)
        .lineLimit(1)
        .truncationMode(.middle)
      Spacer(minLength: 0)
    }
    .padding(.horizontal, FilingPanelStyle.rowPadding)
    .frame(height: FilingPanelStyle.rowHeight)
    .background(background, in: RoundedRectangle(cornerRadius: FilingPanelStyle.rowRadius))
    .contentShape(Rectangle())
    .onTapGesture {
      // One gesture for both, so a single click selects at once instead of waiting out the double-click interval;
      // the second click of a double click carries a click count of 2.
      if (NSApp.currentEvent?.clickCount ?? 1) >= 2 {
        useName()
      } else {
        select()
      }
    }
    .help("Double-click to use this name")
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(file.name)
    .accessibilityValue(accessibilityValue)
    .accessibilityHint("Uses this name for the file")
    .accessibilityAddTraits(highlight.isHighlighted ? [.isButton, .isSelected] : .isButton)
    .accessibilityAction(.default, useName)
    .accessibilityIdentifier("folder-contents-file")
  }

  /// The selection's background, else the warning colour for the conflicting file.
  private var background: Color {
    if highlight.isHighlighted { return highlight.background }
    return isConflict ? Color(nsColor: .systemOrange).opacity(0.3) : .clear
  }

  private var accessibilityValue: String {
    [highlight.isHighlighted ? "selected" : nil, isConflict ? "conflict" : nil]
      .compactMap { $0 }.joined(separator: ", ")
  }

  /// The Finder icon for files named like `name`, from its extension alone (the file itself is not read).
  private static func icon(for name: String) -> NSImage {
    let fileExtension = (name as NSString).pathExtension
    let type = UTType(filenameExtension: fileExtension) ?? .data
    return NSWorkspace.shared.icon(for: type)
  }
}

#if DEBUG
  /// The files of one folder of the sample archive, read synchronously, which a preview can afford.
  @MainActor
  private func sampleContents(of folder: String) -> FolderContents {
    do {
      let index = try PickerSampleArchive.create().index()
      return .files(folder: folder, try index.files(in: folder))
    } catch {
      return .failed(folder: folder, message: "The sample archive could not be built: \(error)")
    }
  }

  #Preview("Files") {
    FolderContentsListing(
      contents: sampleContents(of: "Kommunikation/Ilmnet Internet/Rechnungen"),
      conflictingName: nil,
      listHeight: .constant(120), isCollapsed: .constant(false), maxListHeight: 400
    )
    .frame(width: 340, height: 160)
  }

  #Preview("Selected") {
    let contents = sampleContents(of: "Kommunikation/Ilmnet Internet/Rechnungen")
    FolderContentsListing(
      contents: contents, selectedURL: contents.firstFileURL, conflictingName: nil,
      isListFocused: true, listHeight: .constant(120), isCollapsed: .constant(false),
      maxListHeight: 400
    )
    .frame(width: 340, height: 160)
  }

  #Preview("Conflict") {
    FolderContentsListing(
      contents: sampleContents(of: "Kommunikation/Ilmnet Internet/Rechnungen"),
      conflictingName: "2033-07-19 gutschrift störung.pdf", listHeight: .constant(60),
      isCollapsed: .constant(false), maxListHeight: 400
    )
    .frame(width: 340, height: 100)
  }

  #Preview("New folder") {
    FolderContentsListing(
      contents: .notOnDisk, conflictingName: nil, listHeight: .constant(60),
      isCollapsed: .constant(false), maxListHeight: 400
    )
    .frame(width: 340, height: 100)
  }

  #Preview("Failed") {
    FolderContentsListing(
      contents: .failed(
        folder: "Reisen/Reiseplanung Ideen", message: "The folder no longer exists."),
      conflictingName: nil, listHeight: .constant(60), isCollapsed: .constant(false),
      maxListHeight: 400
    )
    .frame(width: 340, height: 100)
  }

  /// Folder contents fed by a sample picker, with focus of its own.
  private struct PickerFolderContentsPreview: View {
    @State private var model = DestinationPickerModel.sample { $0.filterText = "rechnungen" }
    @FocusState private var isFocused: Bool?

    var body: some View {
      FolderContentsView(
        model: model, focus: $isFocused, field: true, listHeight: .constant(120),
        isCollapsed: .constant(false), maxListHeight: 400)
    }
  }

  #Preview("From the picker") {
    PickerFolderContentsPreview()
      .frame(width: 340, height: 160)
  }

  extension FolderContents {
    /// The first listed file, for previews.
    fileprivate var firstFileURL: URL? {
      if case .files(_, let files) = self { return files.first?.url }
      return nil
    }
  }
#endif
