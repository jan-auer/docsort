import DocsortCore
import SwiftUI

/// The inboxes in sidebar order, with an editable name, the folder path and the folder's status.
///
/// Rows reorder by drag; a row whose folder is not OK offers **Choose…** in its status cell, and every row offers
/// **Choose Folder…** and **Remove** in its context menu.
struct InboxTable: View {
  /// The inboxes, in sidebar order.
  let inboxes: [ConfiguredInbox]
  /// The selected inbox, which **−** removes.
  @Binding var selection: InboxFolder.ID?
  /// What the table's controls do.
  let actions: FolderSettingsActions

  var body: some View {
    Table(of: ConfiguredInbox.self, selection: $selection) {
      TableColumn("Name") { inbox in
        InboxNameField(inbox: inbox) { label in
          actions.relabelInbox(inbox.id, label)
        }
      }
      .width(min: 100, ideal: 150)
      TableColumn("Folder") { inbox in
        Text(inbox.folder.displayPath)
          .lineLimit(1)
          .truncationMode(.middle)
          .help(inbox.folder.reference.lastKnownPath)
      }
      .width(min: 140, ideal: 240)
      TableColumn("Status") { inbox in
        InboxStatusCell(availability: inbox.availability) {
          actions.chooseInboxFolder(inbox.id)
        }
      }
      .width(min: 100, ideal: 170)
    } rows: {
      ForEach(inboxes) { inbox in
        TableRow(inbox)
          .draggable(inbox.id.uuidString)
      }
      .dropDestination(for: String.self) { insertionIndex, draggedIDs in
        moveInboxes(withIDs: draggedIDs, to: insertionIndex)
      }
    }
    .contextMenu(forSelectionType: InboxFolder.ID.self) { ids in
      if let id = ids.first {
        Button("Choose Folder…") { actions.chooseInboxFolder(id) }
        Button("Remove Inbox") {
          actions.removeInbox(id)
          if selection == id { selection = nil }
        }
      }
    }
    .accessibilityIdentifier("settings-inbox-table")
  }

  /// Moves the dragged rows, named by their inbox ids, before the row at `insertionIndex`.
  private func moveInboxes(withIDs draggedIDs: [String], to insertionIndex: Int) {
    let offsets = IndexSet(
      draggedIDs.compactMap(UUID.init(uuidString:)).compactMap { id in
        inboxes.firstIndex { $0.id == id }
      })
    guard !offsets.isEmpty else { return }
    actions.moveInboxes(offsets, insertionIndex)
  }
}

/// An inbox's name, edited in place; blank shows the folder name. The edit is applied on Return or when the field
/// loses focus, not on every keystroke.
private struct InboxNameField: View {
  let inbox: ConfiguredInbox
  let relabel: (String) -> Void

  @State private var draft = ""
  @FocusState private var isFocused: Bool

  var body: some View {
    TextField("Name", text: $draft, prompt: Text(inbox.inbox.folder.folderName))
      .textFieldStyle(.plain)
      .labelsHidden()
      .focused($isFocused)
      .onSubmit { relabel(draft) }
      .onChange(of: isFocused) { _, isFocused in
        if !isFocused { relabel(draft) }
      }
      .onChange(of: inbox.inbox.label, initial: true) { _, label in
        draft = label ?? ""
      }
      .accessibilityIdentifier("settings-inbox-name")
  }
}

/// "OK", or the folder's problem with **Choose…** to pick it again.
private struct InboxStatusCell: View {
  let availability: FolderAvailability
  let chooseFolder: () -> Void

  var body: some View {
    if availability.needsAttention {
      HStack(spacing: 6) {
        Label(availability.settingsStatusText, systemImage: "exclamationmark.triangle.fill")
          .symbolRenderingMode(.multicolor)
          .lineLimit(1)
          .truncationMode(.tail)
          .help(availability.settingsStatusText)
        Spacer(minLength: 4)
        Button("Choose…", action: chooseFolder)
          .controlSize(.small)
          .accessibilityIdentifier("settings-inbox-choose")
      }
    } else {
      Text(availability.settingsStatusText)
        .foregroundStyle(.secondary)
    }
  }
}

#if DEBUG
  #Preview("Inboxes") {
    @Previewable @State var selection: InboxFolder.ID?
    InboxTable(inboxes: SampleFolders.inboxesWithProblems, selection: $selection, actions: .none)
      .frame(width: 600, height: 170)
  }
#endif
