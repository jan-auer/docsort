import DocsortCore
import SwiftUI

/// The destination picker: the search field, the destination line under it (the folder a file would go to, its full
/// path shown once), an edge-to-edge folder list and the New Folder button under the list (`docs/design/ux.md`, "Destination picker"); see ``PickerContract`` for how the filing panel embeds it.
///
/// The panel owns focus: it passes its focus binding and maps ``PickerField`` into its own focus values with
/// `field`. The picker moves focus only between its own two fields (the filter and the new-folder name); everything
/// else it reports as a ``PickerEvent``.
///
/// ## Keys
///
/// While one of the picker's fields has focus, a ``PickerKeyMonitor`` hands the picker's keys to ``handle(_:)``
/// before the text field, the focus system or the menu see them, so Tab, ⇧Tab, Return, Esc and the arrows never
/// move focus or the caret by themselves. → and ← still move the caret while the filter has text: → steps in only
/// with the caret at the end, ← and ⌫ step out only with an empty filter.
///
/// ## Accessibility
///
/// Identifiers: `picker` (the whole picker), `picker-filter`, `picker-filter-clear`, `picker-list`,
/// `picker-new-folder-button`, `picker-refresh-button` (value `refreshing` while the index is rebuilt),
/// `picker-new-folder-name`, `picker-new-folder-notice`. Every list row is one element: folder rows have the
/// identifier `picker-row` and their display path as label (`Konrad/Physiotherapie`); the "this folder" row is
/// `picker-this-folder` labelled "<name>, this folder"; the create row is `picker-create-row` labelled "New Folder “…”
/// in …". A highlighted row has the value `highlighted` (`chosen` when it is the chosen destination) and the
/// selected trait; other rows have an empty value. Activating a row (VoiceOver's
/// default action) does what a double click does; folders with subfolders also offer "Show subfolders".
struct DestinationPickerView<FocusValue: Hashable>: View {
  @Bindable var model: DestinationPickerModel
  let focus: FocusState<FocusValue?>.Binding
  /// Maps the picker's fields into the panel's focus values.
  let field: (PickerField) -> FocusValue

  @State private var keyMonitor = PickerKeyMonitor()
  @State private var filterSelection: TextSelection?

  init(
    model: DestinationPickerModel, focus: FocusState<FocusValue?>.Binding,
    field: @escaping (PickerField) -> FocusValue
  ) {
    self.model = model
    self.focus = focus
    self.field = field
  }

  var body: some View {
    VStack(spacing: 0) {
      PickerFilterField(
        focusState: focusedField == .filter ? .focused : .unfocused,
        hasText: !model.filterText.isEmpty,
        clear: {
          model.filterText = ""
          focus.wrappedValue = field(.filter)
        }
      ) {
        TextField(
          "Destination filter", text: $model.filterText, selection: $filterSelection,
          prompt: Text(model.filterPlaceholder)
        )
        .labelsHidden()
        .focused(focus, equals: field(.filter))
        .accessibilityIdentifier("picker-filter")
      }
      .padding(.horizontal, FilingPanelStyle.edgeMargin)
      .padding(.top, 10)
      DestinationLine(destination: model.destinationPath) { path in
        model.jump(to: path)
        focus.wrappedValue = field(.filter)
      }
      .padding(.horizontal, FilingPanelStyle.edgeMargin + 2)
      .padding(.top, 7)
      .padding(.bottom, 9)
      Divider()
      folderList
        .background(FilingPanelStyle.listBackground)
      Divider()
      bottomBar
    }
    .background(PickerKeyMonitorAnchor(monitor: keyMonitor))
    .accessibilityElement(children: .contain)
    .accessibilityIdentifier("picker")
    .onChange(of: focusedField, initial: true) { previousField, focusedField in
      if focusedField == nil {
        keyMonitor.stop()
      } else {
        keyMonitor.start { key in handle(key) }
      }
      if focusedField == .filter, previousField != .filter {
        placeFilterCaretAtEnd()
      }
    }
    .onChange(of: model.newFolderDraft == nil) { _, draftEnded in
      // The new-folder row and its field are gone. After a cancel, focus goes back to the filter; after a choice,
      // the panel moves it on (`.chose` to the name field), and taking it here would race with that.
      guard draftEnded, model.lastDraftEnding == .cancelled,
        focus.wrappedValue == field(.newFolderName) || focus.wrappedValue == nil
      else { return }
      focus.wrappedValue = field(.filter)
    }
    .onDisappear { keyMonitor.stop() }
  }

  // MARK: Focus and keys

  /// Which of the picker's fields has focus, if any.
  private var focusedField: PickerField? {
    let focused = focus.wrappedValue
    if focused == field(.filter) { return .filter }
    if focused == field(.newFolderName) { return .newFolderName }
    return nil
  }

  /// Puts the filter's caret after its last character, so text typed in the sidebar continues the query instead of
  /// replacing it, and → can step in at once.
  ///
  /// SwiftUI's text field selects all of its text when it gains focus, which happens after this focus change; so the
  /// caret is placed again on the next turn of the main actor, once the field has taken focus.
  private func placeFilterCaretAtEnd() {
    filterSelection = TextSelection(insertionPoint: model.filterText.endIndex)
    Task { @MainActor in
      filterSelection = TextSelection(insertionPoint: model.filterText.endIndex)
    }
  }

  /// Whether the filter's caret sits at the end of its text (or nothing is known about it, as right after the
  /// picker set the text).
  private var isFilterCaretAtEnd: Bool {
    guard let filterSelection else { return true }
    switch filterSelection.indices {
    case .selection(let range):
      return range.isEmpty && range.lowerBound == model.filterText.endIndex
    default:
      return false
    }
  }

  /// Turns a key pressed in one of the picker's fields into the model's intent: the whole key map in one place.
  private func handle(_ key: PickerKey) -> KeyPress.Result {
    switch focusedField {
    case .filter: handleInFilter(key)
    case .newFolderName: handleInNewFolderName(key)
    case nil: .ignored
    }
  }

  private func handleInFilter(_ key: PickerKey) -> KeyPress.Result {
    switch key {
    case .upArrow:
      model.moveHighlight(by: -1)
    case .downArrow:
      model.moveHighlight(by: 1)
    case .rightArrow:
      guard isFilterCaretAtEnd else { return .ignored }
      model.stepIn()
    case .leftArrow:
      guard model.filterText.isEmpty else { return .ignored }
      model.stepOut()
    case .delete:
      guard model.filterText.isEmpty else { return .ignored }
      model.deleteBackward()
    case .commandUpArrow:
      model.jumpToRoot()
    case .tab, .returnKey:
      model.chooseHighlighted()
    case .shiftTab:
      model.stepBack()
    case .escape:
      model.escape()
    case .shiftCommandN:
      beginNewFolder()
    case .commandReturn:
      model.requestMove()
    }
    return .handled
  }

  private func handleInNewFolderName(_ key: PickerKey) -> KeyPress.Result {
    switch key {
    case .tab, .returnKey:
      model.confirmNewFolder()
    case .escape, .shiftTab:
      model.cancelNewFolder()
    case .commandReturn:
      model.confirmNewFolderAndMove()
    case .upArrow, .downArrow, .rightArrow, .leftArrow, .delete, .commandUpArrow, .shiftCommandN:
      return .ignored
    }
    return .handled
  }

  /// ⇧⌘N or the New Folder button: opens the new-folder row, which takes focus when it appears. Focusing its field
  /// here, before the field exists, would only resign the filter and leave nothing focused.
  private func beginNewFolder() {
    model.beginNewFolder()
  }

  // MARK: List

  private var folderList: some View {
    ScrollViewReader { proxy in
      ScrollView {
        LazyVStack(alignment: .leading, spacing: 0) {
          ForEach(model.sections) { section in
            if let title = section.title {
              PickerSectionHeader(title: title)
            }
            ForEach(Array(section.rows.enumerated()), id: \.element.id) { position, row in
              rowView(row)
                .id(row.id)
              if case .currentFolder = row.kind, position < section.rows.count - 1 {
                Divider()
                  .padding(.horizontal, FilingPanelStyle.rowPadding)
                  .padding(.vertical, 4)
              }
            }
          }
          if model.sections.isEmpty {
            PickerInfoRow(text: "No folders.")
              .padding(.horizontal, FilingPanelStyle.rowPadding)
          }
        }
        .padding(.horizontal, FilingPanelStyle.listInset)
        .padding(.vertical, 4)
      }
      .onChange(of: model.highlightedRowID) { _, id in
        guard let id else { return }
        proxy.scrollTo(id)
      }
      .onChange(of: model.newFolderDraft != nil) { _, isNaming in
        guard isNaming, let draftRow = model.rows.first(where: { $0.kind == .newFolderDraft })
        else { return }
        proxy.scrollTo(draftRow.id)
      }
    }
    .frame(minHeight: 96)
    .accessibilityElement(children: .contain)
    .accessibilityLabel("Folders")
    .accessibilityIdentifier("picker-list")
  }

  /// How `row` is highlighted now.
  private func highlight(of row: PickerRow) -> RowHighlight {
    guard row.id == model.highlightedRowID else { return .none }
    return focusedField == nil ? .unfocused : .focused
  }

  @ViewBuilder
  private func rowView(_ row: PickerRow) -> some View {
    let highlight = highlight(of: row)
    switch row.kind {
    case .currentFolder(let path):
      let title = ArchivePath.title(of: path)
      PickerCurrentFolderRow(
        title: title, isNew: model.pendingFolders.contains(path), isChosen: model.isChosen(row),
        highlight: highlight
      )
      .modifier(
        PickerRowChrome(
          identifier: "picker-this-folder", label: "\(title), this folder", highlight: highlight,
          isChosen: model.isChosen(row), click: { click(row) }, open: { open(row) }))
    case .folder(let folder):
      PickerFolderRow(folder: folder, isChosen: model.isChosen(row), highlight: highlight) {
        stepIn(row)
      }
      .modifier(
        PickerRowChrome(
          identifier: "picker-row", label: folder.displayPath, highlight: highlight,
          isChosen: model.isChosen(row), click: { click(row) }, open: { open(row) },
          namedActions: folder.hasSubfolders ? [("Show subfolders", { stepIn(row) })] : []))
    case .createFolder(let name, let parent, let problem):
      let createRow = PickerCreateFolderRow(
        name: name, parent: parent, problem: problem, highlight: highlight)
      createRow
        .modifier(
          PickerRowChrome(
            identifier: "picker-create-row", label: createRow.title, highlight: highlight,
            click: { confirmCreateRow(row) }, open: { confirmCreateRow(row) }))
    case .newFolderDraft:
      NewFolderRowView(model: model, focus: focus, nameField: field(.newFolderName))
    case .indexing:
      PickerInfoRow(text: "Indexing archive…")
        .padding(.horizontal, FilingPanelStyle.rowPadding)
    case .nothingInScope(let scope):
      PickerInfoRow(text: "Nothing in \(ArchivePath.title(of: scope)) matches.")
        .padding(.horizontal, FilingPanelStyle.rowPadding)
        .accessibilityIdentifier("picker-nothing-in-scope")
    }
  }

  /// A single click: highlights the row and brings focus into the picker.
  private func click(_ row: PickerRow) {
    model.highlight(row.id)
    focus.wrappedValue = field(.filter)
  }

  /// A click on the create row: creates its folder (pending until the move), as ⇧⌘N does.
  private func confirmCreateRow(_ row: PickerRow) {
    model.highlight(row.id)
    model.confirmCreateRow()
  }

  /// A double click: steps into a folder with subfolders, chooses anything else.
  private func open(_ row: PickerRow) {
    model.activate(row.id)
  }

  /// The chevron: highlights the folder and steps into it.
  private func stepIn(_ row: PickerRow) {
    model.highlight(row.id)
    model.stepIn()
    focus.wrappedValue = field(.filter)
  }

  // MARK: Bottom bar

  /// The New Folder button (its tooltip names the parent and the shortcut), the refresh button, and the keys that
  /// step into and out of folders.
  private var bottomBar: some View {
    let title = "New Folder in \(model.newFolderParentTitle)"
    return HStack(spacing: 6) {
      Button(action: beginNewFolder) {
        Label("New Folder", systemImage: "folder.badge.plus")
          .contentShape(Rectangle())
      }
      .buttonStyle(.borderless)
      .controlSize(.small)
      .disabled(model.newFolderDraft != nil)
      .help("\(title) (⇧⌘N)")
      .accessibilityLabel(title)
      .accessibilityIdentifier("picker-new-folder-button")
      .layoutPriority(1)
      refreshButton
      Spacer(minLength: 0)
      Text("→ into folder · ← out")
        .font(.footnote)
        .foregroundStyle(.tertiary)
        .lineLimit(1)
        .accessibilityIdentifier("picker-navigation-hint")
    }
    .padding(.horizontal, FilingPanelStyle.edgeMargin - 2)
    .frame(height: 28)
  }

  /// A quiet button that rebuilds the archive index, showing a small spinner in its place while that runs; the list
  /// keeps the previous index meanwhile.
  private var refreshButton: some View {
    Button(action: model.requestRefresh) {
      ZStack {
        if model.isRebuildingIndex {
          ProgressView()
            .controlSize(.mini)
            .transition(.opacity)
        } else {
          Image(systemName: "arrow.clockwise")
            .imageScale(.small)
            .foregroundStyle(.secondary)
            .transition(.opacity)
        }
      }
      .frame(width: 20, height: 20)
      .contentShape(Rectangle())
      .animation(.easeInOut(duration: 0.15), value: model.isRebuildingIndex)
    }
    .buttonStyle(.borderless)
    .disabled(model.isRebuildingIndex)
    .help("Refresh folders (⌘R)")
    .accessibilityLabel("Refresh folders")
    .accessibilityValue(model.isRebuildingIndex ? "refreshing" : "")
    .accessibilityIdentifier("picker-refresh-button")
  }
}

#if DEBUG
  /// Hosts a picker with its own focus state, as the filing panel would.
  private struct DestinationPickerPreview: View {
    let model: DestinationPickerModel
    @FocusState private var focus: PickerField?

    var body: some View {
      DestinationPickerView(model: model, focus: $focus) { $0 }
        .frame(width: 340, height: 360)
        .onAppear { focus = .filter }
    }
  }

  #Preview("Root with Recent") {
    DestinationPickerPreview(model: .sample())
  }

  #Preview("Inside a folder") {
    DestinationPickerPreview(model: .sample { $0.jump(to: "Gesundheit") })
  }

  #Preview("Search with matches") {
    DestinationPickerPreview(model: .sample { $0.filterText = "physio" })
  }

  #Preview("Soft scope: in folder and elsewhere") {
    DestinationPickerPreview(
      model: .sample { model in
        model.jump(to: "Gesundheit")
        model.filterText = "noten"
      })
  }

  #Preview("Soft scope: chosen") {
    DestinationPickerPreview(
      model: .sample { model in
        model.jump(to: "Gesundheit")
        model.filterText = "physio"
        model.chooseHighlighted()
      })
  }

  #Preview("Create row") {
    DestinationPickerPreview(model: .sample { $0.filterText = "Kleingarten Am Weidenbach" })
  }

  #Preview("New folder, existing name") {
    DestinationPickerPreview(
      model: .sample { model in
        model.jump(to: "Reisen")
        model.beginNewFolder()
        model.newFolderName = "reiseplanung ideen"
      })
  }

  #Preview("New folder, nested") {
    DestinationPickerPreview(
      model: .sample { model in
        model.jump(to: "Reisen")
        model.beginNewFolder()
        model.newFolderName = "2032-09 Besuch Matthias Westerholm/Bahn"
      })
  }

  #Preview("Chosen destination") {
    DestinationPickerPreview(
      model: .sample { model in
        model.filterText = "rechnungen"
        model.chooseHighlighted()
      })
  }

  #Preview("Indexing") {
    DestinationPickerPreview(
      model: DestinationPickerModel(
        folderFiles: ArchiveFolderFileListing(), recents: PickerSampleArchive.recents))
  }
#endif
