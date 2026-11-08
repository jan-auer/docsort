import DocsortCore
import SwiftUI

/// The inbox list: one section per inbox (label and number of files still to file), its files oldest first, files in
/// subfolders under a disclosure row for their folder.
///
/// Selecting a row selects the file in the window, and the preview and filing panel follow. With a file selected,
/// typing a printable character starts the destination filter with it; Tab and Return move focus to the filter;
/// → / ← expand and collapse a selected group. An empty inbox shows "No files", an unreachable one a row saying why,
/// with a button to Settings.
struct InboxSidebar: View {
  /// The window's state.
  @Bindable var model: MainWindowModel

  @FocusState private var isFocused: Bool
  @Environment(\.openSettings) private var openSettings

  var body: some View {
    List(selection: $model.sidebarSelection) {
      ForEach(model.inboxes.sections) { section in
        Section {
          content(of: section)
        } header: {
          header(of: section)
        }
      }
    }
    .listStyle(.sidebar)
    .focused($isFocused)
    .onChange(of: isFocused) { _, isFocused in
      if isFocused {
        model.focus = .sidebar
      } else if model.focus == .sidebar {
        model.focus = nil
      }
    }
    .onChange(of: model.focusRequest) { _, request in
      if request?.target == .sidebar { isFocused = true }
    }
    .onChange(of: model.focus) { _, focus in
      // A text field took focus outside SwiftUI's focus system; keep the focus state in step with it.
      if focus != nil, focus != .sidebar, isFocused { isFocused = false }
    }
    .onKeyPress(phases: .down, action: handle)
    .accessibilityIdentifier("sidebar-list")
  }

  private func header(of section: InboxSection) -> some View {
    HStack {
      Text(section.label)
      Spacer()
      let unhandledCount = section.rows.count(where: \.isUnhandled)
      if unhandledCount > 0 {
        Text("\(unhandledCount)")
          .monospacedDigit()
          .foregroundStyle(.secondary)
      }
    }
    .accessibilityIdentifier("sidebar-section-header")
  }

  @ViewBuilder private func content(of section: InboxSection) -> some View {
    switch section.content {
    case .scanning:
      Text("Scanning…")
        .foregroundStyle(.secondary)
        .selectionDisabled()
    case .listing(let entries, _):
      if entries.isEmpty {
        Text("No files")
          .foregroundStyle(.tertiary)
          .selectionDisabled()
          .accessibilityIdentifier("sidebar-no-files")
      } else {
        ForEach(entries) { entry in
          switch entry {
          case .row(let row):
            InboxRowView(row: row)
              .tag(SidebarRowID.item(row.id))
              .contextMenu { rowMenu(for: row.id) }
          case .group(let group):
            DisclosureGroup(isExpanded: expansion(of: group)) {
              ForEach(group.rows) { row in
                InboxRowView(row: row)
                  .tag(SidebarRowID.item(row.id))
                  .contextMenu { rowMenu(for: row.id) }
              }
            } label: {
              Label(group.name, systemImage: "folder")
                .lineLimit(1)
                .truncationMode(.middle)
                .tag(SidebarRowID.group(group.url))
                .accessibilityIdentifier("sidebar-group")
            }
          }
        }
      }
    case .unreachable(let problem):
      VStack(alignment: .leading, spacing: 6) {
        Label(Self.text(for: problem), systemImage: "exclamationmark.triangle")
          .foregroundStyle(.secondary)
          .lineLimit(3)
        Button("Settings…") { openSettings() }
          .controlSize(.small)
      }
      .selectionDisabled()
      .accessibilityElement(children: .contain)
      .accessibilityIdentifier("sidebar-unreachable")
    }
  }

  /// The context menu of the file row `id`: Open, Reveal in Finder and Move to Trash for an unhandled file, Open,
  /// Reveal in Finder and Move Back to Inbox for a filed one, Put Back for a trashed one.
  @ViewBuilder private func rowMenu(for id: InboxItemID) -> some View {
    if let file = model.file(id) {
      if !file.isTrashed {
        Button("Open") { FileActions.open(file.url) }
        Button("Reveal in Finder") { FileActions.revealInFinder(file.url) }
        Divider()
      }
      switch file.returnToInboxAction {
      case .moveBack:
        Button("Move Back to Inbox") { model.returnToInbox(file) }
          .disabled(!model.canReturnToInbox(file))
      case .putBack:
        Button("Put Back") { model.returnToInbox(file) }
          .disabled(!model.canReturnToInbox(file))
      case nil:
        Button("Move to Trash") { model.trash(file) }
          .disabled(!model.canTrash(file))
      }
    }
  }

  private func expansion(of group: InboxGroup) -> Binding<Bool> {
    Binding {
      !model.collapsedGroups.contains(group.url)
    } set: { isExpanded in
      if isExpanded {
        model.collapsedGroups.remove(group.url)
      } else {
        model.collapsedGroups.insert(group.url)
      }
    }
  }

  private func handle(_ press: KeyPress) -> KeyPress.Result {
    switch press.key {
    case .return, .tab:
      guard let file = model.selectedFile, !file.isTrashed else { return .ignored }
      model.requestFocus(.destinationFilter)
      return .handled
    case .rightArrow, .leftArrow:
      guard case .group(let url) = model.sidebarSelection else { return .ignored }
      if press.key == .rightArrow {
        model.collapsedGroups.remove(url)
      } else {
        model.collapsedGroups.insert(url)
      }
      return .handled
    default:
      break
    }
    guard press.modifiers.isDisjoint(with: [.command, .control, .option]),
      Self.isPrintable(press.characters), model.canChooseDestination
    else {
      return .ignored
    }
    model.startDestinationFilter(with: press.characters)
    return .handled
  }

  /// Whether `characters` is text to search for: not empty, not a space (Space is Quick Look), and free of control
  /// and function-key characters.
  private static func isPrintable(_ characters: String) -> Bool {
    guard !characters.isEmpty, characters != " " else { return false }
    return characters.unicodeScalars.allSatisfy { scalar in
      !CharacterSet.controlCharacters.contains(scalar) && !(0xF700...0xF8FF).contains(scalar.value)
    }
  }

  private static func text(for problem: InboxProblem) -> String {
    switch problem {
    case .folderNotFound(let path): "Folder not found: \(path)"
    case .notAFolder(let path): "Not a folder: \(path)"
    case .unreadable(let path, let reason): "\(path) can’t be read: \(reason)"
    }
  }
}

#if DEBUG
  #Preview {
    SidebarColumn {
      InboxSidebar(
        model: .preview(
          folders: .preview(archiveRoot: SampleFolders.archiveRoot, inboxes: SampleFolders.inboxes),
          inboxes: SampleInboxes.library()))
    }
    .frame(width: 260, height: 480)
  }
#endif
